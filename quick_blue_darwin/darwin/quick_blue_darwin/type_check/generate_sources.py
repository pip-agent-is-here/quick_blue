#!/usr/bin/env python3
"""Generate the type-check copies of the Darwin plugin sources.

The harness must compile on Linux, but the hand-written plugin and the
Pigeon-generated file are platform-gated:

  * Messages.g.swift has `#if os(iOS) / #elseif os(macOS) / #else #error(...)`,
    so on Linux it refuses to compile at all.
  * QuickBlueDarwinPlugin.swift only imports Flutter/UIKit/AccessorySetupKit
    under `#if os(iOS)`, so on Linux the FlutterPlugin conformance and the
    AccessorySetupKit coordinator would not resolve.

Both are handled with ONE mechanical rewrite: the platform token `os(iOS)`
becomes `(os(iOS) || QUICK_BLUE_TYPE_CHECK_DARWIN)`. The harness compiles with
`-D QUICK_BLUE_TYPE_CHECK_DARWIN`, so the iOS code paths are enabled while the
original files on disk are never modified. Any edit to the originals is
reflected on the next run because the copies are always regenerated here.

This is not a source of truth: the copies live under Sources/<target>/ and are
overwritten on every run.
"""
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parent / "Sources" / "quick_blue_darwin"
DST = HERE / "Sources" / "QuickBlueDarwinPluginTypeCheck"
TOKEN = "QUICK_BLUE_TYPE_CHECK_DARWIN"
SOURCES = ("QuickBlueDarwinPlugin.swift", "Messages.g.swift")


def transform(text: str) -> str:
    return text.replace("os(iOS)", "(os(iOS) || %s)" % TOKEN)


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    for name in SOURCES:
        origin = SRC / name
        out = DST / name
        out.write_text(transform(origin.read_text()))
        print("generated %s from %s" % (out.relative_to(HERE), origin))


if __name__ == "__main__":
    main()
