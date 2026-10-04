import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue_linux/quick_blue_linux.dart';
import 'package:quick_blue_linux/src/connection_lease.dart';

/// In-memory [ConnectionLeaseBus] recording every call, so the lease's locking,
/// naming and last-client rules run without a system bus.
final class _FakeBus implements ConnectionLeaseBus {
  _FakeBus() : uniqueName = ':1.42';

  @override
  final String uniqueName;

  final Set<String> ownedNames = {};
  final List<String> requestCalls = [];
  final List<String> releaseCalls = [];
  int listNamesCalls = 0;

  /// When non-null, every requestName for a matching name returns this reply
  /// instead of the normal ownership simulation.
  DBusRequestNameReply Function(String name)? forcedReply;

  @override
  Future<DBusRequestNameReply> requestName(
    String name, {
    Set<DBusRequestNameFlag> flags = const {},
  }) async {
    requestCalls.add(name);
    final forced = forcedReply;
    if (forced != null) {
      return forced(name);
    }
    if (flags.contains(DBusRequestNameFlag.doNotQueue) &&
        ownedNames.contains(name)) {
      return DBusRequestNameReply.exists;
    }
    ownedNames.add(name);
    return DBusRequestNameReply.primaryOwner;
  }

  @override
  Future<void> releaseName(String name) async {
    releaseCalls.add(name);
    ownedNames.remove(name);
  }

  @override
  Future<List<String>> listNames() async {
    listNamesCalls += 1;
    return {'org.freedesktop.DBus', 'org.bluez', ...ownedNames}.toList();
  }
}

void main() {
  const testPid = 42;

  group('connectionLeaseNamePrefix', () {
    test('names are process-scoped and device-scoped', () {
      final prefix = connectionLeaseNamePrefix(
        'AA:BB:CC:DD:EE:FF',
        pid: testPid,
      );
      expect(prefix, startsWith('dev.quick_blue.Connection.p42.d'));
      expect(prefix.split('.p42.d').last.length, 16);
    });

    test('different devices hash differently within one process', () {
      final a = connectionLeaseNamePrefix('AA:BB:CC:DD:EE:01', pid: testPid);
      final b = connectionLeaseNamePrefix('AA:BB:CC:DD:EE:02', pid: testPid);
      expect(a, isNot(equals(b)));
    });

    test('the same device hashes identically across processes', () {
      final a = connectionLeaseNamePrefix(
        'AA:BB:CC:DD:EE:FF',
        pid: testPid - 1,
      );
      final b = connectionLeaseNamePrefix('AA:BB:CC:DD:EE:FF', pid: testPid);
      expect(
        a.split('.d').last,
        equals(b.split('.d').last),
        reason:
            'the per-device lock only works if both engines derive the '
            'same name for the same device',
      );
    });
  });

  group('connectionLeaseClientName', () {
    test('appends the sanitized unique name', () {
      final name = connectionLeaseClientName(
        'AA:BB:CC:DD:EE:FF',
        pid: 42,
        uniqueName: ':1.23',
      );
      expect(name, endsWith('.Client1_23'));
      expect(name, contains('.d'));
    });

    test('rejects a bus connection without a unique name', () {
      expect(
        () => connectionLeaseClientName(
          'AA:BB:CC:DD:EE:FF',
          pid: 42,
          uniqueName: '',
        ),
        throwsStateError,
      );
    });
  });

  group('hasOtherConnectionClients', () {
    const testPid = 42;
    final prefix = connectionLeaseNamePrefix('AA:BB:CC:DD:EE:FF', pid: testPid);

    test('ignores the name being released', () {
      expect(
        hasOtherConnectionClients(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          pid: testPid,
          ownedName: '$prefix.Client1',
          busNames: ['$prefix.Client1'],
        ),
        isFalse,
      );
    });

    test('detects another engine still holding the device', () {
      expect(
        hasOtherConnectionClients(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          pid: testPid,
          ownedName: '$prefix.Client1',
          busNames: ['$prefix.Client1', '$prefix.Client2'],
        ),
        isTrue,
      );
    });

    test(
      'does not confuse this device with another device of the same process',
      () {
        final otherDevicePrefix = connectionLeaseNamePrefix(
          'AA:BB:CC:DD:EE:02',
          pid: testPid,
        );
        expect(
          hasOtherConnectionClients(
            deviceId: 'AA:BB:CC:DD:EE:FF',
            pid: testPid,
            ownedName: '$prefix.Client1',
            busNames: ['$prefix.Client1', '$otherDevicePrefix.Client2'],
          ),
          isFalse,
          reason: 'the last-client check must be per device, not per process',
        );
      },
    );
  });

  group('DbusConnectionLease (with a fake bus)', () {
    test(
      'attach takes the lock, registers the client and releases the lock',
      () async {
        final bus = _FakeBus();
        final lease = DbusConnectionLease.withBus(bus);

        await lease.attach('AA:BB:CC:DD:EE:FF');

        final lockCalls = bus.requestCalls
            .where((name) => name.endsWith('.Lock'))
            .length;
        expect(lockCalls, 1);
        expect(
          bus.ownedNames.single.endsWith('.Client1_42'),
          isTrue,
          reason:
              'the client name is registered while the lock is held, and the '
              'lock is released afterwards',
        );
        expect(bus.releaseCalls.single.endsWith('.Lock'), isTrue);
      },
    );

    test('a failed client registration still releases the lock', () async {
      final bus = _FakeBus()
        ..forcedReply = (name) => name.endsWith('.Lock')
            ? DBusRequestNameReply.primaryOwner
            : DBusRequestNameReply.exists;
      final lease = DbusConnectionLease.withBus(bus);

      await expectLater(lease.attach('AA:BB:CC:DD:EE:FF'), throwsStateError);
      expect(
        bus.ownedNames.where((name) => name.endsWith('.Lock')),
        isEmpty,
        reason: 'the lock must not leak when the client name is refused',
      );
    });

    test('a stale lock is retried until it is released', () async {
      final staleLockName =
          '${connectionLeaseNamePrefix('AA:BB:CC:DD:EE:FF', pid: testPid)}.Lock';
      final bus = _FakeBus()..ownedNames.add(staleLockName);
      final lease = DbusConnectionLease.withBus(bus);

      final attach = lease.attach('AA:BB:CC:DD:EE:FF');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Simulate the stale holder going away.
      bus.ownedNames.removeWhere((name) => name.endsWith('.Lock'));

      await attach;
      expect(
        bus.ownedNames.single.endsWith('.Client1_42'),
        isTrue,
        reason: 'once the stale lock clears, attach completes',
      );
    });

    test('a permanently stale lock times out instead of hanging', () async {
      final bus = _FakeBus()
        ..forcedReply = (name) => name.endsWith('.Lock')
            ? DBusRequestNameReply.exists
            : DBusRequestNameReply.primaryOwner;
      final lease = DbusConnectionLease.withBus(bus);

      await expectLater(lease.attach('AA:BB:CC:DD:EE:FF'), throwsStateError);
    });

    test(
      'detach releases the client name and detects the last client',
      () async {
        final bus = _FakeBus();
        final lease = DbusConnectionLease.withBus(bus);
        await lease.attach('AA:BB:CC:DD:EE:FF');
        bus.requestCalls.clear();

        var onLastClientCalls = 0;
        await lease.detach(
          'AA:BB:CC:DD:EE:FF',
          () async => onLastClientCalls += 1,
        );

        expect(onLastClientCalls, 1);
        expect(bus.ownedNames, isEmpty);
      },
    );

    test(
      'detach keeps the shared connection while another engine holds it',
      () async {
        final bus = _FakeBus();
        final lease = DbusConnectionLease.withBus(bus);
        await lease.attach('AA:BB:CC:DD:EE:FF');

        // A second engine holds another client name for the same device. Its
        // device hash is identical across processes, so model it by suffixing the
        // same prefix with a different client id.
        final ourPrefix = bus.ownedNames.single.split('.Client').first;
        bus.ownedNames.add('$ourPrefix.Client2');

        var onLastClientCalls = 0;
        await lease.detach(
          'AA:BB:CC:DD:EE:FF',
          () async => onLastClientCalls += 1,
        );

        expect(
          onLastClientCalls,
          0,
          reason:
              'the shared BlueZ connection must survive while another client '
              'is still registered',
        );
        expect(bus.ownedNames.contains('$ourPrefix.Client2'), isTrue);
      },
    );

    test('attach and detach serialize per device through the lock', () async {
      final bus = _FakeBus();
      final lease = DbusConnectionLease.withBus(bus);

      final order = <String>[];
      await Future.wait<void>([
        lease
            .attach('AA:BB:CC:DD:EE:FF')
            .then<void>((_) => order.add('attach-1')),
        lease
            .attach('AA:BB:CC:DD:EE:FF')
            .then<void>((_) => order.add('attach-2')),
      ]);

      expect(order, ['attach-1', 'attach-2']);
      expect(bus.ownedNames.where((name) => name.endsWith('.Lock')), isEmpty);
    });
  });
}
