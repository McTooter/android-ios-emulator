#!/usr/bin/env python3
"""Validate a local ARM64 Android guest bundle without executing any guest code."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

REQUIRED_KEYS = (
    "formatVersion",
    "guestName",
    "androidApiLevel",
    "architecture",
    "machine",
    "kernel",
    "systemImage",
    "vendorImage",
    "userdataImage",
)


def validate(manifest_path: Path) -> list[str]:
    errors: list[str] = []
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return [f"manifest not found: {manifest_path}"]
    except json.JSONDecodeError as exc:
        return [f"invalid JSON: {exc}"]

    for key in REQUIRED_KEYS:
        if key not in data:
            errors.append(f"missing manifest key: {key}")

    if data.get("architecture") != "arm64-v8a":
        errors.append("architecture must be arm64-v8a for the initial iPad target")
    if data.get("machine") != "virt":
        errors.append("machine must be virt for the initial QEMU guest target")
    if not isinstance(data.get("androidApiLevel"), int):
        errors.append("androidApiLevel must be an integer")

    bundle_dir = manifest_path.parent
    for key in ("kernel", "initrd", "systemImage", "vendorImage", "userdataImage"):
        value = data.get(key)
        if not isinstance(value, str) or not value:
            errors.append(f"{key} must name a file in the guest bundle")
            continue
        candidate = (bundle_dir / value).resolve()
        if bundle_dir.resolve() not in candidate.parents:
            errors.append(f"{key} must remain inside the guest bundle")
        elif not candidate.is_file():
            errors.append(f"missing guest file for {key}: {value}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Guest manifest is valid: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
