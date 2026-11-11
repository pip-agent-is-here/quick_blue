import 'dart:async';
import 'dart:typed_data';

import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';
import 'package:test/test.dart';

import 'test_support/fake_quick_blue_platform.dart';

void main() {
  test(
    'invalidated queued notification listener cannot acquire a peer claim',
    () async {
      final gate = Completer<void>();
      final platform = FakeQuickBluePlatform(
        setNotifiableCompletions: [gate],
        discoveredServices: [
          BluetoothService(
            deviceId: 'device-a',
            uuid: 'service-a',
            characteristics: const ['characteristic-a'],
          ),
        ],
      );
      addTearDown(platform.dispose);
      final device = platform.device('device-a');
      final gatt = await device.discoverGatt();
      final direct = device.characteristic('service-a', 'characteristic-a');
      final peer = direct.notifications().listen((_) {});
      await pumpEventQueue();
      final errors = <Object>[];
      var done = false;
      final bound = gatt
          .boundCharacteristic('characteristic-a')
          .notifications()
          .listen(
            (_) {},
            onError: errors.add,
            onDone: () {
              done = true;
            },
          );
      await pumpEventQueue();
      platform.handleGattServicesChanged('device-a');
      gate.complete();
      await pumpEventQueue();
      await bound.cancel();
      final beforePeerCancel = List<String>.of(platform.calls);
      await peer.cancel();
      expect(errors, [
        isA<QuickBlueException>().having(
          (e) => e.code,
          'code',
          QuickBlueErrorCode.invalidState,
        ),
      ]);
      expect(done, isTrue);
      expect(
        beforePeerCancel.where((c) => c.startsWith('setNotifiable')),
        hasLength(1),
      );
      expect(platform.calls.where((c) => c.endsWith('disabled')), hasLength(1));
    },
  );

  test(
    'invalidation does not block teardown of an acquired bound claim',
    () async {
      final platform = FakeQuickBluePlatform(
        discoveredServices: [
          BluetoothService(
            deviceId: 'device-a',
            uuid: 'service-a',
            characteristics: const ['characteristic-a'],
          ),
        ],
      );
      addTearDown(platform.dispose);
      final gatt = await platform.device('device-a').discoverGatt();
      final subscription = gatt
          .boundCharacteristic('characteristic-a')
          .notifications()
          .listen((_) {});
      await pumpEventQueue();
      platform.handleGattServicesChanged('device-a');
      await subscription.cancel();
      expect(platform.calls.where((c) => c.endsWith('disabled')), hasLength(1));
    },
  );

  for (final operation in ['read', 'write', 'setNotifiable', 'notifications']) {
    for (final binding in ['bound', 'direct', 'valid-bound']) {
      test('$operation security retry respects $binding snapshot', () async {
        final gate = Completer<void>();
        final security = QuickBlueSecurityException(
          nativeDomain: 'test',
          nativeCode: null,
          message: 'security rejected',
          reason: QuickBlueSecurityErrorReason.insufficientAuthorization,
          operation: operation,
          deviceId: 'device-a',
        );
        final platform = FakeQuickBluePlatform(
          discoveredServices: [
            BluetoothService(
              deviceId: 'device-a',
              uuid: 'service-a',
              characteristics: const ['characteristic-a'],
            ),
          ],
          readValueError: security,
          writeValueError: security,
          setNotifiableError: security,
          securityRecoveryResult: QuickBlueSecurityRecoveryResult.recovered,
          securityRecoveryCompleter: gate,
        );
        addTearDown(platform.dispose);
        final device = platform.device('device-a');
        final gatt = await device.discoverGatt();
        final handle = binding == 'direct'
            ? device.characteristic('service-a', 'characteristic-a')
            : gatt.boundCharacteristic('characteristic-a');
        Object? failure;
        var notificationDone = false;
        StreamSubscription<Uint8List>? subscription;
        addTearDown(() async {
          await subscription?.cancel();
        });
        Future<void> execute() async {
          switch (operation) {
            case 'read':
              await handle.read();
            case 'write':
              await handle.write(Uint8List(1), BleOutputProperty.withResponse);
            case 'setNotifiable':
              await handle.setNotifiable(BleInputProperty.notification);
            case 'notifications':
              subscription = handle.notifications().listen(
                (_) {},
                onError: (Object e) {
                  failure = e;
                },
                onDone: () {
                  notificationDone = true;
                },
              );
          }
        }

        final pending = execute().catchError((Object e) {
          failure = e;
        });
        await pumpEventQueue();
        expect(
          platform.calls.where((c) => c.startsWith('performSecurityRecovery')),
          hasLength(1),
        );
        if (binding != 'valid-bound') {
          platform.handleGattServicesChanged('device-a');
        }
        platform.readValueError = null;
        platform.writeValueError = null;
        platform.setNotifiableError = null;
        gate.complete();
        await pending;
        await pumpEventQueue();
        final prefix = operation == 'read'
            ? 'readValue'
            : operation == 'write'
            ? 'writeValue'
            : 'setNotifiable';
        expect(
          platform.calls.where((c) => c.startsWith(prefix)),
          hasLength(binding == 'bound' ? 1 : 2),
        );
        if (binding == 'bound') {
          expect(
            failure,
            isA<QuickBlueException>().having(
              (e) => e.code,
              'code',
              QuickBlueErrorCode.invalidState,
            ),
          );
          if (operation == 'notifications') expect(notificationDone, isTrue);
        } else {
          expect(failure, isNull);
        }
        await subscription?.cancel();
      }, timeout: const Timeout(Duration(seconds: 5)));
    }
  }
}
