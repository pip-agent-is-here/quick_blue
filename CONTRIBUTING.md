# Contributing to quick_blue

This repository is a Dart workspace for a federated Flutter plugin. Preserve
the package boundaries: shared APIs and models belong in
`quick_blue_platform_interface`, while platform behavior belongs in the owning
platform package.

## Ongoing knowledge maintenance (people and agents)

Before work, read `docs/index.md`, the relevant OKF concepts, and
`docs/testing.md`. The plain Markdown OKF bundle in `docs/` is the source of
truth for detailed repository documentation; the website and READMEs are entry
points, not independent authorities. Trace claims to cited implementation/tests;
if docs and code disagree, resolve intended behavior and fix the discrepancy in
the same change rather than following stale prose.

For every change to behavior, APIs, examples, supported platforms, setup, or
workflows, update the affected OKF concepts in the same change. Keep source
references, examples, index descriptions/cross-links, public README entry points,
and `quick_blue/CHANGELOG.md` current as applicable. Follow
`docs/maintenance.md` for OKF v0.2 metadata and reserved-file rules. In the handoff,
list the docs updated or explain concretely why no documentation was affected.

Before marking work ready, run the documentation validation commands in
`docs/maintenance.md` (`scripts/check-okf.py` and `git diff --check`), verify claims
against cited code/tests, exercise changed examples, and run the site build when
configured plus the relevant checks in `docs/testing.md`. Report exact commands,
results, blockers and unverified claims; structural checks are not hardware proof.
Documentation maintenance is part of every ordinary change, not a later pass.

## Set up and analyze

Run dependency setup from the repository root:

```sh
flutter pub get
```

Format touched Dart files and run static analysis:

```sh
dart format .
flutter analyze
```

Run the package-focused tests relevant to the change:

```sh
cd quick_blue_platform_interface && flutter test
cd quick_blue_darwin && flutter test
cd quick_blue/example && flutter test
```

## Hardware-backed integration tests

Changes to scanning, connections, service discovery, reads, writes,
notifications, device switching, or platform Bluetooth behavior require a
hardware-backed test when the target host and BLE hardware are available.

From `quick_blue/example`, run the cross-platform smoke test on the affected
target. For example:

```sh
QUICK_BLUE_HIDE_TEST_WINDOW=1 \
  flutter test integration_test/ble_smoke_test.dart -d macos

QUICK_BLUE_HIDE_TEST_WINDOW=1 \
  xvfb-run -a flutter test integration_test/ble_smoke_test.dart -d linux
```

The smoke test requires Bluetooth permission, powered-on Bluetooth hardware,
and nearby advertisements. It includes service discovery and read coverage;
writes are opt-in because there is no universally safe writable
characteristic. See
[the example workflows](docs/example-app.md) for device profiles and
[the test-input reference](docs/example-options.md) for all supported Dart defines.

The example also includes focused UI, multi-engine, and performance tests:

```sh
flutter test integration_test/ble_ui_switch_test.dart -d macos

flutter test integration_test/android_multi_engine_test.dart -d ANDROID_DEVICE \
  --dart-define=QUICK_BLUE_MULTI_ENGINE_DEVICE_ID='DEVICE_ID'

flutter test integration_test/ios_multi_engine_test.dart -d IOS_DEVICE \
  --dart-define=QUICK_BLUE_MULTI_ENGINE_DEVICE_ID='DEVICE_UUID' \
  --dart-define=QUICK_BLUE_MULTI_ENGINE_SERVICE_UUID='SERVICE_UUID' \
  --dart-define=QUICK_BLUE_MULTI_ENGINE_CHARACTERISTIC_UUID='CHARACTERISTIC_UUID'

flutter test integration_test/ble_characteristic_benchmark_test.dart -d macos \
  --dart-define=QUICK_BLUE_BENCHMARK_DEVICE_ID='DEVICE_ID' \
  --dart-define=QUICK_BLUE_BENCHMARK_NOTIFY_SERVICE_UUID='SERVICE_UUID' \
  --dart-define=QUICK_BLUE_BENCHMARK_NOTIFY_CHARACTERISTIC_UUID='CHARACTERISTIC_UUID'
```

### Windows VM smoke test

Run the Windows smoke test through Dockur from the repository root:

```sh
QUICK_BLUE_WINDOWS_USB_VENDOR_ID=0x0bda \
QUICK_BLUE_WINDOWS_USB_PRODUCT_ID=0x8771 \
  scripts/windows-integration-test.sh
```

The script starts `dockurr/windows`, passes through the selected USB Bluetooth
adapter, and runs the example smoke test on Windows. VM state persists under
`.dart_tool/dockur_windows/`, and the guest reuses
`C:\quick_blue_workspace\quick_blue` for Flutter build caches.

Set `QUICK_BLUE_WINDOWS_CLEAN_WORKTREE=1` to refresh the guest checkout without
reinstalling Windows. Use `QUICK_BLUE_WINDOWS_RESET=1` only when the VM disk
must be rebuilt.

## Generated Pigeon code

Pigeon schemas and generated bindings must stay synchronized. Do not hand-edit
generated `messages.g.*` files.

For the Android/main plugin:

```sh
cd quick_blue
dart run pigeon --input pigeons/messages.dart
```

For iOS and macOS:

```sh
cd quick_blue_darwin
dart run pigeon --input pigeons/messages.dart
```

For Windows:

```sh
cd quick_blue_windows
dart run pigeon --input pigeons/messages.dart
```

Inspect the resulting generated-file diff before submitting the change.

## Releasing

All five packages share one version. `scripts/publish-packages.sh` enforces the
invariants — every pubspec carries the same `version`, each platform package
depends on `quick_blue_platform_interface` at that version, and the app-facing
package pins all federated packages — then runs the publish steps:

```sh
scripts/publish-packages.sh --dry-run   # CI runs this on every change
scripts/publish-packages.sh --publish   # real publish, run manually
```

Before releasing:

1. Fold the `Unreleased` entries into a dated `## [x.y.z]` heading in
   `quick_blue/CHANGELOG.md` (CI fails when the pubspec version has no
   changelog heading).
2. Bump `version` in every package's `pubspec.yaml` in the same change.
3. Update the federated dependency constraints (the script reports any that
   drift).
4. Run `scripts/publish-packages.sh --dry-run` and confirm the smoke tests for
   every platform you can reach.
