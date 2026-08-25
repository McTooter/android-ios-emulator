#!/usr/bin/env python3
"""Validate a local ARM64 Android guest bundle without executing any guest code."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

BASE_REQUIRED_KEYS = (
    "formatVersion",
    "guestName",
    "androidApiLevel",
    "architecture",
    "machine",
)

LEGACY_KERNEL_KEYS = ("kernel", "initrd", "systemImage", "vendorImage", "userdataImage")


def validate(manifest_path: Path) -> list[str]:
    errors: list[str] = []
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return [f"manifest not found: {manifest_path}"]
    except json.JSONDecodeError as exc:
        return [f"invalid JSON: {exc}"]

    for key in BASE_REQUIRED_KEYS:
        if key not in data:
            errors.append(f"missing manifest key: {key}")

    if data.get("architecture") != "arm64-v8a":
        errors.append("architecture must be arm64-v8a for the initial iPad target")
    if data.get("machine") != "virt":
        errors.append("machine must be virt for the initial QEMU guest target")
    if not isinstance(data.get("androidApiLevel"), int):
        errors.append("androidApiLevel must be an integer")

    bundle_dir = manifest_path.parent.resolve()

    def check_file(label: str, value: object) -> None:
        if not isinstance(value, str) or not value:
            errors.append(f"{label} must name a file in the guest bundle")
            return
        candidate = (bundle_dir / value).resolve()
        if bundle_dir not in candidate.parents:
            errors.append(f"{label} must remain inside the guest bundle")
        elif not candidate.is_file():
            errors.append(f"missing guest file for {label}: {value}")

    boot_mode = data.get("bootMode", "kernel-initrd")
    if boot_mode == "kernel-initrd":
        for key in LEGACY_KERNEL_KEYS:
            check_file(key, data.get(key))
    elif boot_mode == "uefi":
        check_file("firmware", data.get("firmware"))
        firmware_code = data.get("firmwareCode")
        if firmware_code is not None:
            check_file("firmwareCode", firmware_code)
        disks = data.get("disks")
        if not isinstance(disks, list) or not disks:
            errors.append("disks must be a non-empty list for UEFI guests")
        else:
            seen_ids: set[str] = set()
            for index, disk in enumerate(disks):
                if not isinstance(disk, dict):
                    errors.append(f"disks[{index}] must be an object")
                    continue
                disk_id = disk.get("id")
                if not isinstance(disk_id, str) or not disk_id:
                    errors.append(f"disks[{index}].id must be a non-empty string")
                elif disk_id in seen_ids:
                    errors.append(f"duplicate disk id: {disk_id}")
                else:
                    seen_ids.add(disk_id)
                disk_format = disk.get("format", "qcow2")
                if disk_format not in ("raw", "qcow2"):
                    errors.append(f"disks[{index}].format must be raw or qcow2")
                check_file(f"disks[{index}].path", disk.get("path"))
    else:
        errors.append("bootMode must be kernel-initrd or uefi")

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
