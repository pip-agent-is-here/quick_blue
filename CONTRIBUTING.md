# Contributing to quick_blue

This is a Dart workspace for a federated Flutter plugin. See
[the package map](docs/overview.md#package-map) and `AGENTS.md` for repository
constraints, including package boundaries and observable async failures.

For read-only inquiries, start with [the index](docs/index.md), relevant concepts
and their cited implementation/tests. Before changing the repository, follow:

- [Maintenance](docs/maintenance.md): preparation, same-change documentation,
  OKF rules, complete documentation/site gates and commit conventions.
- [Testing](docs/testing.md): dependency setup, touched-file formatting, analysis,
  package/native checks, Pigeon regeneration, hardware BLE and Windows VM recipes,
  and precise evidence/blocker reporting.
  Its evidence-storage section separates Git reproducibility from durable raw artifacts.
- [Example workflows](docs/example-app.md) and
  [test inputs](docs/example-options.md): hardware profiles and scenario selection.

Before releasing, follow [release metadata](docs/maintenance.md#release-metadata).
Publication is a separate authorized manual action, not an ordinary contribution.
