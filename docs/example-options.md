---
type: "Reference"
title: "Integration-test Dart defines"
description: "Look up compile-time test inputs and their source defaults."
tags: ["example", "testing", "configuration"]
generated: {"by": "builder/gpt-6.1-sol", "at": "2026-10-08T14:25:41+00:00"}
sources: [{"id": "source1", "resource": "../quick_blue/example/integration_test/ble_smoke_test.dart"}, {"id": "source2", "resource": "../quick_blue/example/integration_test/ble_characteristic_benchmark_test.dart"}, {"id": "source3", "resource": "../quick_blue/example/integration_test/ble_lifecycle_stress_test.dart"}, {"id": "source4", "resource": "../quick_blue/example/integration_test/ble_ui_switch_test.dart"}, {"id": "source5", "resource": "../quick_blue/example/integration_test/macos_ble_switch_test.dart"}, {"id": "source6", "resource": "../quick_blue/example/integration_test/android_multi_engine_test.dart"}, {"id": "source7", "resource": "../quick_blue/example/integration_test/ios_multi_engine_test.dart"}]
---

# Integration-test Dart defines

Pass these as `--dart-define=NAME=value` to the selected test from
`quick_blue/example`. Values are compile-time inputs, not shell environment
variables. The tables record source defaults, not safe production settings.
An empty identifier/UUID must be filled for targeted tests; see
[example workflows](example-app.md) for required combinations and skip behavior.

## Smoke

| Define | Type | Source default |
| --- | --- | --- |
| `QUICK_BLUE_SMOKE_BLUETOOTH_READY_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_SMOKE_CONNECT` | String | `''` |
| `QUICK_BLUE_SMOKE_CONNECT_TIMEOUT_SECONDS` | int | `12` |
| `QUICK_BLUE_SMOKE_DEVICE_ID` | String | `''` |
| `QUICK_BLUE_SMOKE_DISCONNECT_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_SMOKE_DUMP_ADVERTISEMENTS` | bool | `false` |
| `QUICK_BLUE_SMOKE_EXPECTED_ADVERTISED_SERVICE_UUIDS` | String | `''` |
| `QUICK_BLUE_SMOKE_EXPECTED_MANUFACTURER_DATA_HEX` | String | `''` |
| `QUICK_BLUE_SMOKE_EXPECTED_SERVICE_UUIDS` | String | `''` |
| `QUICK_BLUE_SMOKE_MAX_CONNECT_ATTEMPTS` | int | `3` |
| `QUICK_BLUE_SMOKE_MIN_RSSI` | int | `0` |
| `QUICK_BLUE_SMOKE_NAME_PATTERN` | String | `''` |
| `QUICK_BLUE_SMOKE_PROFILE` | String | `''` |
| `QUICK_BLUE_SMOKE_PROFILE_JSON` | String | `''` |
| `QUICK_BLUE_SMOKE_READ` | String | `''` |
| `QUICK_BLUE_SMOKE_READ_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_SMOKE_SCAN_SECONDS` | int | `12` |
| `QUICK_BLUE_SMOKE_SERVICE_TIMEOUT_SECONDS` | int | `15` |
| `QUICK_BLUE_SMOKE_SERVICE_UUIDS` | String | `''` |
| `QUICK_BLUE_SMOKE_WRITE_CHARACTERISTIC_UUID` | String | `''` |
| `QUICK_BLUE_SMOKE_WRITE_HEX` | String | `''` |
| `QUICK_BLUE_SMOKE_WRITE_SERVICE_UUID` | String | `''` |
| `QUICK_BLUE_SMOKE_WRITE_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_SMOKE_WRITE_WITHOUT_RESPONSE` | bool | `false` |

## Benchmark

| Define | Type | Source default |
| --- | --- | --- |
| `QUICK_BLUE_BENCHMARK_BLUETOOTH_READY_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_BENCHMARK_CONNECT_TIMEOUT_SECONDS` | int | `15` |
| `QUICK_BLUE_BENCHMARK_DEVICE_ID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_DURATION_SECONDS` | int | `30` |
| `QUICK_BLUE_BENCHMARK_NAME_PATTERN` | String | `''` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_CHARACTERISTIC_UUID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_SERVICE_UUID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_CHARACTERISTIC_UUID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_COMMAND_HEX` | String | `''` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_DELAY_MILLISECONDS` | int | `0` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_ITERATIONS` | int | `1` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_SERVICE_UUID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_TIMEOUT_SECONDS` | int | `5` |
| `QUICK_BLUE_BENCHMARK_NOTIFY_WRITE_WITHOUT_RESPONSE` | bool | `true` |
| `QUICK_BLUE_BENCHMARK_READ_CHARACTERISTIC_UUID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_READ_DELAY_MILLISECONDS` | int | `0` |
| `QUICK_BLUE_BENCHMARK_READ_ITERATIONS` | int | `100` |
| `QUICK_BLUE_BENCHMARK_READ_SERVICE_UUID` | String | `''` |
| `QUICK_BLUE_BENCHMARK_READ_TIMEOUT_SECONDS` | int | `5` |
| `QUICK_BLUE_BENCHMARK_SCAN_SECONDS` | int | `12` |
| `QUICK_BLUE_BENCHMARK_SCAN_SERVICE_UUIDS` | String | `''` |
| `QUICK_BLUE_BENCHMARK_SEQUENCE_LITTLE_ENDIAN` | bool | `true` |
| `QUICK_BLUE_BENCHMARK_SEQUENCE_OFFSET` | int | `-1` |
| `QUICK_BLUE_BENCHMARK_SEQUENCE_WIDTH_BYTES` | int | `2` |
| `QUICK_BLUE_BENCHMARK_SERVICE_TIMEOUT_SECONDS` | int | `15` |
| `QUICK_BLUE_BENCHMARK_USE_INDICATIONS` | bool | `false` |

## Stress

| Define | Type | Source default |
| --- | --- | --- |
| `QUICK_BLUE_STRESS_BLUETOOTH_READY_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_STRESS_FIRST_NAME_PATTERN` | String | `''` |
| `QUICK_BLUE_STRESS_ITERATIONS` | int | `3` |
| `QUICK_BLUE_STRESS_OPERATION_TIMEOUT_SECONDS` | int | `15` |
| `QUICK_BLUE_STRESS_SCAN_SECONDS` | int | `15` |
| `QUICK_BLUE_STRESS_SECOND_NAME_PATTERN` | String | `''` |

## Device switching

| Define | Type | Source default |
| --- | --- | --- |
| `QUICK_BLUE_SWITCH_BLUETOOTH_READY_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_SWITCH_CONNECT_TIMEOUT_SECONDS` | int | `8` |
| `QUICK_BLUE_SWITCH_DELAY_MILLISECONDS` | int | `600` |
| `QUICK_BLUE_SWITCH_FIRST_NAME_PATTERN` | String | `'govee'` |
| `QUICK_BLUE_SWITCH_SCAN_SECONDS` | int | `15` |
| `QUICK_BLUE_SWITCH_SECOND_CONNECT_TIMEOUT_SECONDS` | int | `ble_ui_switch_test.dart: 15; macos_ble_switch_test.dart: 12` |
| `QUICK_BLUE_SWITCH_SECOND_NAME_PATTERN` | String | `'nest\\s*hub\|nesthub'` |

## Multi-engine

| Define | Type | Source default |
| --- | --- | --- |
| `QUICK_BLUE_MULTI_ENGINE_CHARACTERISTIC_UUID` | String | `''` |
| `QUICK_BLUE_MULTI_ENGINE_DEVICE_ID` | String | `''` |
| `QUICK_BLUE_MULTI_ENGINE_SERVICE_UUID` | String | `''` |

## Important interpretations

- `*_SECONDS` and `*_MILLISECONDS` are duration units; scan duration differs from
  connect/read/service deadlines.
- Smoke `CONNECT` / `READ` are strings: empty lets profile settings apply;
  explicit `false` disables that phase. Profile JSON overlays the named profile,
  and explicit defines override profile values.
- Empty smoke filters use the test/profile defaults. Manufacturer-data hex is a
  prefix, and names are case-insensitive regular expressions.
- Write hex and UUIDs must describe a known safe test peripheral. Never enable
  writes simply to make a smoke test pass.
- Benchmark sequence offset `-1` disables sequence checking; widths are 1, 2 or
  4 bytes. Write-without-response does not acknowledge application delivery.
- Switch timeout defaults differ between UI and macOS suites; preserve the
  distinction rather than copying a single default to both.
- `QUICK_BLUE_HIDE_TEST_WINDOW` and `QUICK_BLUE_WINDOWS_*` are shell/script
  environment settings, not Dart defines. See [testing](testing.md).
