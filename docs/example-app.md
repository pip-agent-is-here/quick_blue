---
type: "Playbook"
title: "Use the BLE explorer and test profiles"
description: "Exercise device workflows and choose an integration test that proves the intended behavior."
tags: ["example", "testing"]

sources: [{"id": "source1", "resource": "../quick_blue/example/lib/src/ble_explorer_controller.dart"}, {"id": "source2", "resource": "../quick_blue/example/README.md"}, {"id": "source3", "resource": "../quick_blue/example/integration_test/ble_smoke_test.dart"}, {"id": "source4", "resource": "../quick_blue/example/integration_test/ble_characteristic_benchmark_test.dart"}]
---

# Use the BLE explorer and test profiles

Run the explorer from `quick_blue/example` with `flutter run -d TARGET` after
root `flutter pub get`. It provides scan controls, device selection, service
inspection and characteristic interaction; its controller is a concrete lifecycle
reference, not a requirement to copy its UI into your app.

## Choose the right hardware test

| Test | Purpose | Important boundary |
| --- | --- | --- |
| `ble_smoke_test.dart` | Scan, connect, discover, read; opt-in write | Missing Bluetooth fails; no universally safe write |
| `android_multi_engine_test.dart` / `ios_multi_engine_test.dart` | Shared native ownership and handoff | Real known device required for BLE cases |
| `ble_ui_switch_test.dart` / `macos_ble_switch_test.dart` | Switch while connect is pending | Can skip on unavailable/unsupported setup |
| `ble_lifecycle_stress_test.dart` | Repeated scan/GATT/teardown races | Connectable readable targets needed |
| `ble_characteristic_benchmark_test.dart` | Throughput, timing, optional command-response | Missing Bluetooth fails; unconfigured/missing target can skip |

A skipped test is not verification. Capture the test's scenario and result, not
just its process exit code. Multi-engine runtime coverage is Android/iOS only.

## Advertisement-only smoke

From `quick_blue/example` on headless Linux:

```sh
QUICK_BLUE_HIDE_TEST_WINDOW=1 \
  xvfb-run -a flutter test integration_test/ble_smoke_test.dart -d linux \
    --dart-define=QUICK_BLUE_SMOKE_PROFILE=valve_lighthouse
```

This profile matches `LHB-*` names and a Lighthouse manufacturer prefix, and skips
connect/read by default. It proves advertisement matching, not GATT behavior.

## Targeted read smoke

Replace `DEVICE_ID` with a real connectable peripheral (shell example):

```sh
flutter test integration_test/ble_smoke_test.dart -d linux \
  --dart-define=QUICK_BLUE_SMOKE_DEVICE_ID='DEVICE_ID' \
  --dart-define=QUICK_BLUE_SMOKE_CONNECT_TIMEOUT_SECONDS=30
```

Smoke prefers common readable characteristics, then falls back to a discovered
readable one. Only enable write defines with a known safe command and writable
UUID pair. A benchmark requires the notify service/characteristic UUIDs; its
reported throughput is specific to your peripheral and host, not a plugin guarantee.

All 66 compile-time inputs, including deadlines omitted from the older example
README, are listed in [Dart defines](example-options.md). See [testing](testing.md)
for baseline, stress, multi-engine and Windows recipes.
