---
type: "Reference"
title: "Pairing and security failures"
description: "Gate bonding APIs and handle coordinated security recovery without blind retries."
tags: ["security", "bonding", "errors"]

sources: [{"id": "source1", "resource": "../quick_blue_platform_interface/lib/src/bluetooth_device.dart"}, {"id": "source2", "resource": "../quick_blue_platform_interface/lib/src/quick_blue_exception.dart"}, {"id": "source3", "resource": "../quick_blue/lib/src/android_security_recovery.dart"}, {"id": "source4", "resource": "../quick_blue_platform_interface/test/bluetooth_device_connection_test.dart"}]
---

# Pairing and security failures

## Pair deliberately

Android exposes query, pair and bond events. Linux exposes query and pair, but
not live bond events. Darwin and Windows do not expose app-initiated pairing.
CoreBluetooth can prompt when a protected attribute is accessed.

Dart fragment in an async function with a BluetoothDevice `device`:

```dart
final capabilities = await QuickBlue.capabilities();
if (capabilities.supportsPairing &&
    await device.bondState() != BluetoothBondState.bonded) {
  await device.pair();
}
if (capabilities.supportsBondStateChanges) {
  await device.waitForBondState(BluetoothBondState.bonded)
      .timeout(const Duration(seconds: 30));
}
```

`waitForBondState` subscribes before reading the current state, avoiding a
snapshot/event race.[^source1] Without live events (Linux), it can return an already
matching snapshot but cannot be relied on to observe a future transition. Gate
it with `supportsBondStateChanges` and supply your own timeout.

## Automatic recovery is bounded

Normal managed connect, read, notification setup and acknowledged-write paths
coordinate one security recovery per device, then retry a rejected operation
once after successful recovery. Android first observes implicit bonding for a
bounded period before attempting explicit bonding; calling `pair()` preemptively
is not required for a protected GATT access.

Do not blindly replay writes for arbitrary transport failures. The security retry
contract concerns a write rejected before application, not proof that a timed-out
write had no side effects.

## Preserve structured diagnostics

Dart error-handling fragment:

```dart
try {
  await device.readValue(serviceId, characteristicId);
} on QuickBlueSecurityException catch (error) {
  if (error.recoveryResult ==
      QuickBlueSecurityRecoveryResult.userActionRequired) {
    // Show actionable system-settings guidance; do not loop indefinitely.
  }
} on QuickBlueGattException catch (error) {
  print('native GATT status: ${error.status}');
}
```

Security errors expose `reason`, `nativeDomain`, `nativeCode`, and `recoveryResult`.
Android non-security GATT failures preserve their numeric `status`, including
vendor values. Connection events can carry an `error` too. Portable
`QuickBlueException.code` values include `unsupported`, `unavailable`,
`invalidState`, `deviceBusy`, `operationFailed`, `notFound`, `ambiguous`, `cancelled`.

See [capabilities](capabilities.md) and [observability privacy](observability.md).

[^source1]: Bond-state wait and pairing handle contract.
