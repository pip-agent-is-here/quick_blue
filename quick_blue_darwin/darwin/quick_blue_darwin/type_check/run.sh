#!/usr/bin/env bash
# Type-check the Darwin BLE plugin on Linux.
#   ./run.sh
# Regenerates the platform-shimmed copies of the two real sources and builds
# the harness package and runs native-boundary tests against framework stubs.
# Exits non-zero on any type error or test failure in the plugin.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer a locally installed toolchain when present (developer machines);
# otherwise use whatever `swift` is on PATH (CI containers ship one).
if [[ -x /home/hermes/.local/opt/swift/usr/bin/swift ]]; then
  export PATH=/home/hermes/.local/opt/swift/usr/bin:$PATH
fi

cd "$DIR"
command -v swift >/dev/null || {
  echo "swift not found; install a Swift 6.x toolchain or run the CI job" >&2
  exit 127
}

"$DIR/generate_sources.sh"
swift test
