import 'dart:async';

import 'package:bluez/bluez.dart';

Future<void> waitForDeviceProperty(
  BlueZDevice device, {
  required String propertyName,
  required bool Function() isReady,
  required Duration timeout,
}) async {
  if (isReady()) {
    return;
  }

  final completer = Completer<void>();
  late final StreamSubscription<List<String>> subscription;
  subscription = device.propertiesChanged.listen(
    (properties) {
      if (properties.contains(propertyName) &&
          isReady() &&
          !completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  try {
    await completer.future.timeout(timeout);
  } finally {
    await subscription.cancel();
  }
}
