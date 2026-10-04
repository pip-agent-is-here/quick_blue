#!/usr/bin/env bash
# Generate the type-check copies of the Darwin plugin sources.
#
# The harness must compile on Linux, but the hand-written plugin and the
# Pigeon-generated file are platform-gated:
#
#   * Messages.g.swift has `#if os(iOS) / #elseif os(macOS) / #else #error(...)`,
#     so on Linux it refuses to compile at all.
#   * QuickBlueDarwinPlugin.swift only imports Flutter/UIKit/AccessorySetupKit
#     under `#if os(iOS)`, so on Linux the FlutterPlugin conformance and the
#     AccessorySetupKit coordinator would not resolve.
#
# Both are handled with ONE mechanical rewrite: the platform token `os(iOS)`
# becomes `(os(iOS) || QUICK_BLUE_TYPE_CHECK_DARWIN)`. The harness compiles with
# `-D QUICK_BLUE_TYPE_CHECK_DARWIN`, so the iOS code paths are enabled while the
# original files on disk are never modified. Any edit to the originals is
# reflected on the next run because the copies are always regenerated here.
#
# This is not a source of truth: the copies live under Sources/<target>/ and are
# overwritten on every run. It relies on nothing but a shell and POSIX sed, so
# it runs in the Swift CI container (which ships no Python).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/../Sources/quick_blue_darwin"
DST="$DIR/Sources/QuickBlueDarwinPluginTypeCheck"
TOKEN="QUICK_BLUE_TYPE_CHECK_DARWIN"
SOURCES=(QuickBlueDarwinPlugin.swift Messages.g.swift)

mkdir -p "$DST"
for name in "${SOURCES[@]}"; do
  sed "s/os(iOS)/(os(iOS) || $TOKEN)/g" "$SRC/$name" > "$DST/$name"
  echo "generated Sources/QuickBlueDarwinPluginTypeCheck/$name from $SRC/$name"
done
