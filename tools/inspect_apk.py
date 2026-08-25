#!/usr/bin/env python3
"""Inspect an APK archive without executing or modifying it."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import zipfile


def inspect_apk(path: Path) -> dict[str, object]:
    with zipfile.ZipFile(path) as apk:
        names = apk.namelist()
        native_abis = sorted({
            parts[1]
            for name in names
            if (parts := name.split("/", 2))[0] == "lib" and len(parts) > 2
        })
        dex_files = sorted(name for name in names if name.endswith(".dex"))
        split_files = sorted(name for name in names if name.endswith(".apk"))
        return {
            "file": str(path),
            "bytes": path.stat().st_size,
            "hasBinaryManifest": "AndroidManifest.xml" in names,
            "dexFiles": dex_files,
            "nativeABIs": native_abis,
            "embeddedSplits": split_files,
            "supportsInitialTarget": "arm64-v8a" in native_abis or not native_abis,
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect_apk(args.apk), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
