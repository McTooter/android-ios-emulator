#!/usr/bin/env python3
"""Patch the pinned UTM Meson cross-file generator for non-runnable iOS targets.

Meson still performs a compiler sanity check during a cross build. The iOS
compiler output cannot execute on the macOS host, so the generated cross file
needs a no-op executable wrapper. This wrapper is used only for configure-time
run checks; it does not execute target binaries.
"""
from __future__ import annotations

import argparse
from pathlib import Path

NEEDLE = '    echo "needs_exe_wrapper = true" >> $cross\n'
INSERT = NEEDLE + '    echo "exe_wrapper = [\'/usr/bin/true\']" >> $cross\n'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    path = args.path
    text = path.read_text(encoding="utf-8")
    if 'echo "exe_wrapper = [\'/usr/bin/true\']" >> $cross' in text:
        return 0
    if NEEDLE not in text:
        raise SystemExit(f"expected Meson cross-file marker not found: {path}")
    path.write_text(text.replace(NEEDLE, INSERT, 1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
