#!/usr/bin/env python3
"""Patch the pinned UTM Meson cross-file generator for non-runnable iOS targets.

Meson performs configure-time compiler sanity checks during a cross build. The
arm64 iOS compiler output cannot execute on the macOS host, so the generated
cross file needs a no-op executable wrapper. This wrapper is used only for
configure-time run checks; it does not execute target binaries.
"""
from __future__ import annotations

import argparse
from pathlib import Path

BINARY_SECTION = '    echo "[binaries]" >> $cross\n'
WRAPPER_LINE = '    echo "exe_wrapper = [\'/usr/bin/true\']" >> $cross\n'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    path = args.path
    text = path.read_text(encoding="utf-8")
    if WRAPPER_LINE in text:
        return 0
    if BINARY_SECTION not in text:
        raise SystemExit(f"expected Meson binaries section not found: {path}")
    path.write_text(text.replace(BINARY_SECTION, BINARY_SECTION + WRAPPER_LINE, 1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
