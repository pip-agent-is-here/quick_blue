import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'availability.g.dart';

/// Resolve lazily: Dart plugin registration can precede JNI registration.
QuickBlueAvailabilityApi? createNativeAvailabilityApi() {
  if (!Platform.isAndroid) return null;
  final engineId = PlatformDispatcher.instance.engineId;
  // BackgroundIsolateBinaryMessenger routes to its registering root engine.
  // A worker has no native engine ID; never invoke JNI's latest-engine fallback.
  if (engineId == null) return null;
  // Never use the preview resolver's default/latest-engine fallback.
  return QuickBlueAvailabilityApi.createWithNativeInteropApi(
    messageChannelSuffix: 'quick_blue.availability.$engineId',
  );
}
