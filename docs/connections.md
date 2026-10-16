---
type: "Reference"
title: "Connection lifetimes and retries"
description: "Choose one-shot or subscription-owned connections and handle overlapping operations."
tags: ["connections", "lifecycle"]

sources: [{"id": "source1", "resource": "../quick_blue_platform_interface/lib/src/bluetooth_device.dart"}, {"id": "source2", "resource": "../quick_blue_platform_interface/lib/src/managed_connection_lifecycle.dart"}, {"id": "source3", "resource": "../quick_blue_platform_interface/test/bluetooth_device_connection_test.dart"}, {"id": "source4", "resource": "../quick_blue/android/src/main/kotlin/com/example/quick_blue/AndroidGattBroker.kt"}]
---

# Connection lifetimes and retries

## One-shot ownership

`device.connect()` waits for a connected event; `disconnect()` detaches this
client. Device connect/disconnect, discovery and MTU methods accept caller-local
`timeout` and `cancellationToken` options. Neither stops native work or releases
ownership. Disconnect when abandoning a timed-out connection; an immediate retry
instead joins outstanding work.

Dart fragment with a BluetoothDevice `device`:

```dart
await device.connect(timeout: const Duration(seconds: 15));
```

`QuickBlueCancellationToken` is one-shot. Cancellation reports `cancelled` with
`failureReason: QuickBlueFailureReason.callerCancelled`; deadlines throw
`TimeoutException`. Without options waits are unbounded. MTU work with no callback
remains outstanding until platform completion or engine disposal. Negative
timeouts fail before work starts; zero follows Dart timer/event-loop ordering.
Timers and token listeners are removed when each caller's wait settles.

Expiration only stops that caller's wait. A late successful connect can still
attach this engine, and cancelling a wait cannot undo a disconnect already
requested. Retries join the outstanding operation rather than starting work
that could consume an old native callback. Late completion retires shared work;
late errors are consumed even if every caller has left. If a callback never
arrives, one operation per device/kind remains quarantined. Each caller can
still set its own deadline; there is no portable abort/reset for pending MTU
work. Managed-connection policy and deprecated static helpers do not acquire
these device-method wait options.

Identical MTU requests share work; a different requested value is rejected while
negotiation is pending. Disconnect or GATT invalidation resets discovery, but
does not provide a portable reset for MTU negotiation.

| Overlap for the same device | Result |
| --- | --- |
| Disconnect during connect | Supersedes connect; old future gets `cancelled` |
| Connect during pending disconnect | Supersedes disconnect; old future gets `cancelled` |
| Same-kind pending connect/disconnect | Callers share outstanding work with independent deadlines |
| Different devices | May connect concurrently |

Service discoveries coalesce; disconnect cancels pending discovery. Android
additionally bounds final-client teardown and ignores retired-GATT callbacks;
this disconnect reconciliation guarantee is Android-specific.[^source4]
Linux's pending property waiter can survive clear and emit after same-address
replacement discovery in the
[fake-BlueZ characterization](limitations.md#linux-gatt-teardown-characterization).
Facade cancellation does not prove this native-session work stopped.

## Managed reconnection

Use this for a feature that should recover after an established link drops.
Dart fragment in an async scope; `device` is a BluetoothDevice:

```dart
final subscription = device.maintainConnection(
  policy: BluetoothReconnectionPolicy(
    maxAttempts: 5,
    initialDelay: const Duration(seconds: 1),
    maxDelay: const Duration(seconds: 20),
    backoffMultiplier: 2,
  ),
).listen(
  (change) => print(change.state),
  onError: (Object error) => print('connection ended: $error'),
);
// Cancel when the feature stops, not immediately after subscribing.
await subscription.cancel();
```

- Listening performs one initial attempt; initial failure ends the stream without
  entering the reconnection policy.
- After link loss, delays grow up to `maxDelay`. `maxAttempts` resets after each
  successful reconnect; `null` means retry until stopped.
- Exhaustion emits the final error and closes the stream.
- Cancellation or `device.disconnect()` stops retries and detaches this client.
- Only one managed connection owns a device per engine. Do not mix it with
  manual `connect()` calls for that device.

For cross-engine handoff, read [multi-engine ownership](multi-engine.md).

## Typed connection failures

Match `QuickBlueException.failureReason` rather than diagnostic text. Its nullable
`QuickBlueFailureReason` values distinguish `connectionFailed`, `callerCancelled`
and `remoteDisconnected`; a reason does not establish whether retrying is safe.

Connection attempts through the static, device and managed APIs classify failures
using operation context. Unexpected loss after an observed connection appears in
`BluetoothConnectionStateChange.error`, even when native status is success; the
original state and status are unchanged. A local disconnect is not a remote
failure. Superseded connection work and discovery cancelled by local disconnect
report `callerCancelled`. Database invalidation uses code `cancelled` without
claiming caller cancellation. Discovery interrupted by remote link loss retains
the remote reason and diagnostic cause in `details`.

Existing codes, messages, native GATT statuses, Darwin domains/codes and security
subclasses remain available. Raw native connection exceptions are wrapped with
`connectionFailed`, retaining the original exception in `details` and preserving
the Dart throw stack. Unknown causes do not acquire a reason from their text.

[^source4]: Android GATT broker disconnect reconciliation.
