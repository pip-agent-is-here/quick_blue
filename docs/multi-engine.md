---
type: "Playbook"
title: "Share a connection across engines"
description: "Attach the receiving engine before detaching the previous owner."
tags: ["connections", "multi-engine"]
generated: {"by": "builder/gpt-6.1-sol", "at": "2026-10-08T14:25:41+00:00"}
sources: [{"id": "source1", "resource": "../quick_blue/android/src/main/kotlin/com/example/quick_blue/ConnectionClientSet.kt"}, {"id": "source2", "resource": "../quick_blue_darwin/darwin/quick_blue_darwin/connection_ownership/Sources/QuickBlueConnectionOwnership/SharedConnectionOwnership.swift"}, {"id": "source3", "resource": "../quick_blue_windows/windows/connection_ownership.h"}, {"id": "source4", "resource": "../quick_blue_linux/lib/src/connection_ownership.dart"}, {"id": "source5", "resource": "../quick_blue/example/integration_test/android_multi_engine_test.dart"}, {"id": "source6", "resource": "../quick_blue/example/integration_test/ios_multi_engine_test.dart"}]
---

# Share a connection across engines

Use this for a foreground UI and a background Flutter engine in the same app
process. Native GATT ownership is coordinated; Dart handles and subscriptions
remain local to each engine. `disconnect()` detaches one engine, and the physical
connection is closed after the final owner detaches.

## Handoff recipe

Conceptual cross-engine sequence, not a single-scope runnable snippet:

```dart
// Receiving engine: attach and establish its own subscriptions first.
await foregroundDevice.connect();
// Old engine: release its subscriptions, then detach.
await backgroundNotifications.cancel();
await backgroundDevice.disconnect();
```

Coordinate these steps with your application's inter-engine messages. Register the
plugin in each engine. Notification claims are reference-counted, so establish
the receiving subscription before releasing the old one when continuity matters.
Shared native ownership does not transfer Dart objects or automatically keep the
application process alive.

Darwin can connect directly to a stable peripheral UUID already known to
CoreBluetooth; a preceding scan is not always necessary.

## Verification boundary

The repository has runtime multi-engine integration suites for Android and iOS.
Linux, macOS and Windows ownership also have unit/native tests, but there is no
matching hardware multi-engine integration suite for each of those targets.
Do not turn implementation support into a claim of universal hardware validation.

See [testing](testing.md) for the Android/iOS commands and
[connections](connections.md) for per-engine lifecycle rules.
