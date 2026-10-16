import 'dart:async';

import 'package:test/test.dart';
import 'package:quick_blue_linux/src/connection_ownership.dart';

void main() {
  test(
    'uncertain membership waits, propagates errors and retries original identity',
    () async {
      final lease = _FakeConnectionLease();
      final ownership = ConnectionOwnership(lease);
      await ownership.attach('device', leaseId: 'original/device');
      lease.detachError = StateError('partial teardown');
      await expectLater(
        ownership.detach('device', onLastClient: () async {}),
        throwsStateError,
      );
      lease.attachGate = Completer<void>();
      var completed = false;
      final retry = ownership
          .attach('device', leaseId: 'replacement/device')
          .then((_) {
            completed = true;
          });
      await pumpEventQueue();
      expect(completed, isFalse);
      expect(ownership.owns('device'), isTrue);
      final failure = expectLater(retry, throwsStateError);
      lease.attachGate!.completeError(StateError('attach reply'));
      await failure;
      expect(completed, isFalse);
      lease.attachGate = null;
      await ownership.attach('device', leaseId: 'replacement/device');
      await ownership.attach('device');
      expect(lease.attachments, List.filled(3, 'original/device'));
      lease.detachError = null;
      await ownership.detach('device', onLastClient: () async {});
      expect(ownership.deviceIds, isEmpty);
    },
  );
  for (final fail in [false, true]) {
    test(
      'pending detach joins reentry and gates attach (fail=$fail)',
      () async {
        final lease = _FakeConnectionLease();
        final ownership = ConnectionOwnership(lease);
        await ownership.attach('device', leaseId: 'adapter-a/device');
        final entered = Completer<void>();
        final proceed = Completer<void>();
        var repeatedCleanups = 0;
        final first = ownership.detach(
          'device',
          onLastClient: () async {
            entered.complete();
            await proceed.future;
            if (fail) throw StateError('late teardown failure');
          },
        );
        await entered.future;
        final repeated = ownership.detach(
          'device',
          onLastClient: () async {
            repeatedCleanups++;
          },
        );
        expect(identical(first, repeated), isTrue);
        expect(ownership.owns('device'), isTrue);
        var attached = false;
        final retry = ownership
            .attach('device', leaseId: 'adapter-b/device')
            .then((_) {
              attached = true;
            });
        await pumpEventQueue();
        expect(attached, isFalse);
        final settlements = [
          for (final future in [first, repeated, retry])
            expectLater(future, fail ? throwsStateError : completes),
        ];
        proceed.complete();
        await Future.wait(settlements);
        expect(repeatedCleanups, 0);
        expect(lease.detachments, ['adapter-a/device']);
        expect(
          lease.attachments,
          fail
              ? ['adapter-a/device']
              : ['adapter-a/device', 'adapter-b/device'],
        );
        await ownership.detach('device', onLastClient: () async {});
        expect(ownership.owns('device'), isFalse);
      },
    );
  }
  test(
    'scoped lease identity is retained across failed detach and retry',
    () async {
      final lease = _FakeConnectionLease(detachError: StateError('failed'));
      final ownership = ConnectionOwnership(lease);
      await ownership.attach('device-a', leaseId: 'adapter-a/device-a');
      await ownership.attach('device-a', leaseId: 'replacement/device-a');
      expect(ownership.deviceIds, ['device-a']);
      expect(lease.attachments, ['adapter-a/device-a']);
      await expectLater(
        ownership.detach('device-a', onLastClient: () async {}),
        throwsStateError,
      );
      expect(ownership.owns('device-a'), isTrue);
      lease.detachError = null;
      await ownership.detach('device-a', onLastClient: () async {});
      expect(lease.detachments, ['adapter-a/device-a', 'adapter-a/device-a']);
      expect(ownership.deviceIds, isEmpty);
    },
  );
  test(
    'successful attachments are tracked and repeated calls are coalesced',
    () async {
      final lease = _FakeConnectionLease();
      final ownership = ConnectionOwnership(lease);

      await ownership.attach('device-a');
      await ownership.attach('device-a');

      expect(ownership.owns('device-a'), isTrue);
      expect(lease.attachments, <String>['device-a']);
    },
  );

  test('failed attachments are not tracked', () async {
    final lease = _FakeConnectionLease(attachError: StateError('failed'));
    final ownership = ConnectionOwnership(lease);

    await expectLater(ownership.attach('device-a'), throwsStateError);
    expect(ownership.owns('device-a'), isFalse);
  });

  test('detach is idempotent and forwards final-client cleanup', () async {
    final lease = _FakeConnectionLease();
    final ownership = ConnectionOwnership(lease);
    await ownership.attach('device-a');
    var cleanups = 0;

    await ownership.detach('device-a', onLastClient: () async => cleanups++);
    await ownership.detach('device-a', onLastClient: () async => cleanups++);

    expect(ownership.owns('device-a'), isFalse);
    expect(lease.detachments, <String>['device-a']);
    expect(cleanups, 1);
  });

  test('failed detach preserves ownership for a retry', () async {
    final lease = _FakeConnectionLease(detachError: StateError('failed'));
    final ownership = ConnectionOwnership(lease);
    await ownership.attach('device-a');

    await expectLater(
      ownership.detach('device-a', onLastClient: () async {}),
      throwsStateError,
    );

    expect(ownership.owns('device-a'), isTrue);
  });
}

class _FakeConnectionLease implements QuickBlueLinuxConnectionLease {
  _FakeConnectionLease({this.attachError, this.detachError});

  final Object? attachError;
  Object? detachError;
  Completer<void>? attachGate;
  final List<String> attachments = <String>[];
  final List<String> detachments = <String>[];

  @override
  Future<void> attach(String deviceId) async {
    attachments.add(deviceId);
    await attachGate?.future;
    if (attachError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> detach(
    String deviceId,
    Future<void> Function() onLastClient,
  ) async {
    detachments.add(deviceId);
    if (detachError case final error?) {
      throw error;
    }
    await onLastClient();
  }
}
