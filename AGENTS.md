# Repository Instructions

For read-only inquiries, read `docs/index.md` and the relevant concepts, then
trace claims to their cited implementation/tests. Before making changes, follow
`docs/maintenance.md` (preparation, same-change documentation, OKF rules and
readiness gates) and `docs/testing.md` (check selection, exact commands and
evidence boundaries). These are the canonical procedures for people and agents.
Follow `docs/testing.md` section "Store reproducibility separately from raw
execution records" for Git versus durable artifact storage.

## Project layout and constraints

This is a Dart workspace for a federated Flutter Bluetooth LE plugin. The root
`pubspec.yaml` defines workspace members; run dependency setup from the root
unless a package-specific procedure says otherwise.

- `quick_blue/`: app-facing facade and Android implementation; delegates other
  platforms to federated packages.
- `quick_blue_platform_interface/`: shared Dart APIs, models and interface tests.
- `quick_blue_darwin/`: iOS/macOS shared Swift implementation.
- `quick_blue_linux/`: BlueZ and generated FFI bindings.
- `quick_blue_windows/`: Windows C++ implementation.
- `quick_blue/example/`: example app for manual and platform verification.

Preserve federated boundaries: shared API/model changes belong in
`quick_blue_platform_interface`; platform behavior belongs in its owning package.
Follow `docs/testing.md` section "Native and generated boundaries" for Pigeon
source/output locations, regeneration and channel/API alignment. Inspect, never
hand-edit, generated bindings.

Do not use `unawaited` futures in Dart code. Await fallible futures or route errors
to an explicit handler so failures are observable. `pubspec.lock` is ignored.
