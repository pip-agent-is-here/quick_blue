import 'dart:isolate';
import 'dart:ui';

import 'package:quick_blue/src/messages.g.dart' as messages;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quick_blue/quick_blue.dart';
import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';
import 'package:quick_blue/src/availability.g.dart';
import 'package:quick_blue_example/multi_engine_worker.dart';

import 'support/multi_engine_test_support.dart';

const _control = MethodChannel('quick_blue.example/multi_engine_control');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('worker isolate retains engine channel availability', (
    tester,
  ) async {
    final token = RootIsolateToken.instance!;
    final result = await Isolate.run(() async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      final channelResult = await messages.QuickBlueApi()
          .isBluetoothAvailable();
      Object publicResult;
      try {
        publicResult = await QuickBlueAndroid().isBluetoothAvailable();
      } catch (error) {
        publicResult = error.toString();
      }
      return <Object>[channelResult, publicResult];
    }).timeout(const Duration(seconds: 30));
    // The actual pre-existing generated channel must work before comparing
    // the public adapter. No mocked messenger or peer-engine routing.
    expect(result[0], isA<bool>());
    expect(result[1], result[0]);
  });

  testWidgets('native availability is engine-scoped and detached handles fail', (
    tester,
  ) async {
    expect(multiEngineWorkerEntrypointReference, isA<Function>());
    // Resolve the first native client only AFTER a second engine registers.
    await startSecondaryEngine();
    var primaryDetached = false;
    try {
      await _control.invokeMethod<void>('disablePrimaryHostChannels');
      final primary = QuickBluePlatform.instance;
      final retained = QuickBlueAvailabilityApi.createWithNativeInteropApi(
        messageChannelSuffix:
            'quick_blue.availability.${PlatformDispatcher.instance.engineId}',
      );
      expect(await primary.isBluetoothAvailable(), isA<bool>());
      expect(
        await callMultiEngineWorker<bool>('isBluetoothAvailable', ''),
        isA<bool>(),
      );
      await stopSecondaryEngine();
      expect(await primary.isBluetoothAvailable(), isA<bool>());
      await startSecondaryEngine();
      await _control.invokeMethod<void>('detachPrimaryPlugin');
      primaryDetached = true;
      await expectLater(
        primary.isBluetoothAvailable(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'unregistered-instance',
          ),
        ),
      );
      // A new lookup must not borrow the still-running secondary engine.
      expect(
        () => QuickBlueAvailabilityApi.createWithNativeInteropApi(
          messageChannelSuffix:
              'quick_blue.availability.${PlatformDispatcher.instance.engineId}',
        ),
        throwsArgumentError,
      );
      expect(
        await callMultiEngineWorker<bool>('isBluetoothAvailable', ''),
        isA<bool>(),
      );
      await _control.invokeMethod<void>('attachPrimaryPlugin');
      primaryDetached = false;
      // Same registered public singleton, same engine, new native registration.
      await _control.invokeMethod<void>('disablePrimaryHostChannels');
      expect(await primary.isBluetoothAvailable(), isA<bool>());
      await expectLater(
        retained.isBluetoothAvailable(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'unregistered-instance',
          ),
        ),
      );
    } finally {
      if (primaryDetached) {
        await _control.invokeMethod<void>('attachPrimaryPlugin');
      }
      await stopSecondaryEngine();
    }
  });
}
