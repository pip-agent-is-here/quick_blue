import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'test_support/fake_quick_blue_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retained raw characteristic value stream delivers after re-listen',
    () async {
      final platform = FakeQuickBluePlatform();
      addTearDown(platform.dispose);
      final stream = platform
          .device('device-a')
          .characteristic('180d', '2a37')
          .valueStream;
      final initialValues = <Uint8List>[];
      final firstSubscription = stream.listen(initialValues.add);
      addTearDown(firstSubscription.cancel);

      platform.handleCharacteristicValueChanged(
        'device-a',
        '180d',
        '2a37',
        Uint8List.fromList(<int>[1]),
      );
      await pumpEventQueue();
      expect(initialValues.map((value) => value.toList()), <List<int>>[
        <int>[1],
      ]);
      await firstSubscription.cancel();

      // Reuse the exact stream, rather than obtaining a new getter result.
      final resumedValues = <Uint8List>[];
      final secondSubscription = stream.listen(resumedValues.add);
      addTearDown(secondSubscription.cancel);
      platform.handleCharacteristicValueChanged(
        'device-a',
        '180d',
        '2a37',
        Uint8List.fromList(<int>[2]),
      );
      await pumpEventQueue();

      expect(resumedValues.map((value) => value.toList()), <List<int>>[
        <int>[2],
      ]);
      expect(
        platform.calls,
        isEmpty,
        reason: 'Raw streams do not enable notifications.',
      );
    },
  );
}
