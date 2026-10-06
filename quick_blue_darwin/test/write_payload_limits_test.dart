import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_blue_darwin/quick_blue_darwin.dart';
import 'package:quick_blue_darwin/src/messages.g.dart' as messages;
import 'package:quick_blue_platform_interface/quick_blue_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const prefix = 'dev.flutter.pigeon.quick_blue_darwin.QuickBlueApi.';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(String method, Future<Object?> Function(Object?) handler) {
    messenger.setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        '$prefix$method',
        messages.QuickBlueApi.pigeonChannelCodec,
      ),
      handler,
    );
  }

  tearDown(() {
    for (final method in ['maximumWriteValueLength', 'writeValue']) {
      messenger.setMockMessageHandler('$prefix$method', null);
    }
    messages.QuickBlueFlutterApi.setUp(null);
  });

  test(
    'device and characteristic query separate native limits without MTU',
    () async {
      final calls = <Object?>[];
      mock('maximumWriteValueLength', (message) async {
        calls.add(message);
        final arguments = message! as List<Object?>;
        return <Object?>[
          arguments[1] == messages.PlatformBleOutputProperty.withResponse
              ? 512
              : 97,
        ];
      });
      final device = QuickBlueDarwin().device('device');
      expect(
        await device.maximumWriteValueLength(BleOutputProperty.withResponse),
        512,
      );
      expect(
        await device
            .characteristic('service', 'char')
            .maximumWriteValueLength(BleOutputProperty.withoutResponse),
        97,
      );
      expect(calls, [
        ['device', messages.PlatformBleOutputProperty.withResponse],
        ['device', messages.PlatformBleOutputProperty.withoutResponse],
      ]);
    },
  );

  test(
    'without-response write awaits native handoff and propagates busy error',
    () async {
      final reply = Completer<Object?>();
      mock('writeValue', (_) => reply.future);
      final characteristic = QuickBlueDarwin()
          .device('device')
          .characteristic('service', 'char');
      var completed = false;
      final write = characteristic.write(
        Uint8List.fromList([1]),
        BleOutputProperty.withoutResponse,
      );
      final expectation = expectLater(
        write,
        throwsA(
          isA<QuickBlueException>().having(
            (error) => error.code,
            'code',
            QuickBlueErrorCode.invalidState,
          ),
        ),
      );
      final observed = write.then<void>(
        (_) {
          completed = true;
        },
        onError: (Object _) {
          completed = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      reply.complete(['InvalidState', 'Native buffer is full', null]);
      await expectation;
      await observed;
      expect(completed, isTrue);
    },
  );
}
