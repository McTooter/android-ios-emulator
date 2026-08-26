#!/usr/bin/env python3
"""Patch UTM's iOS cross-build scripts for host-only configure checks.

The iOS target compiler cannot execute on the macOS host. UTM's dependency
helper and QEMU's own configure script each generate a Meson cross file, so
both generators need a configure-time wrapper. The wrapper prints the numeric
probe result expected by GLib and never executes target binaries.
"""
from __future__ import annotations

import argparse
from pathlib import Path

BINARY_SECTION = '    echo "[binaries]" >> $cross\n'
WRAPPER_LINE = '    echo "exe_wrapper = [\'/bin/sh\', \'-c\', \'printf 0\']" >> $cross\n'
QEMU_CONFIGURE_ANCHOR = '        ./configure --prefix="$PREFIX" --host="$CHOST" $@\n'
QEMU_HOOK_MARKER = '        if [ "$NAME" = "qemu-10.0.12-utm" ]; then\n'
QEMU_CONFIGURE_PATCH = r"""        if [ "$NAME" = "qemu-10.0.12-utm" ]; then
            python3 - configure <<'PY'
from pathlib import Path

configure = Path(__import__('sys').argv[1])
text = configure.read_text(encoding='utf-8')
marker = '  echo "[binaries]" >> $cross\n'
wrapper = "  echo \"exe_wrapper = ['/bin/sh', '-c', 'printf 0']\" >> $cross\n"
properties = '  echo "[properties]" >> $cross\n'
needs_wrapper = "  echo \"needs_exe_wrapper = true\" >> $cross\n"
if wrapper not in text:
    if marker not in text or properties not in text:
        raise SystemExit(f'QEMU Meson binaries marker not found: {configure}')
    text = text.replace(properties, properties + needs_wrapper, 1)
    configure.write_text(text.replace(marker, marker + wrapper, 1), encoding='utf-8')
PY
            grep -n -F "exe_wrapper = ['/bin/sh', '-c', 'printf 0']" configure
        fi
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    path = args.path
    text = path.read_text(encoding="utf-8")
    changed = False

    if WRAPPER_LINE not in text:
        if BINARY_SECTION not in text:
            raise SystemExit(f"expected Meson binaries section not found: {path}")
        text = text.replace(BINARY_SECTION, BINARY_SECTION + WRAPPER_LINE, 1)
        changed = True

    if QEMU_HOOK_MARKER not in text:
        if QEMU_CONFIGURE_ANCHOR not in text:
            raise SystemExit(f"expected generic configure anchor not found: {path}")
        text = text.replace(QEMU_CONFIGURE_ANCHOR, QEMU_CONFIGURE_PATCH + QEMU_CONFIGURE_ANCHOR, 1)
        changed = True

    if changed:
        path.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
