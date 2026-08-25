#!/usr/bin/env python3
"""Generate QEMU arguments for a validated, user-supplied Android ARM64 guest.

This tool only emits arguments. It never launches QEMU, downloads images, changes
entitlements, enables JIT, or attempts to bypass iPadOS security controls.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shlex
import sys

from validate_guest import validate


def load_manifest(manifest_path: Path) -> dict:
    errors = validate(manifest_path)
    if errors:
        raise ValueError("; ".join(errors))
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def bundle_file(bundle_dir: Path, name: str) -> str:
    return str((bundle_dir / name).resolve())


def generate_args(manifest_path: Path, memory_mib: int, cpus: int, acceleration: str) -> list[str]:
    data = load_manifest(manifest_path)
    bundle_dir = manifest_path.parent.resolve()

    # The default is portable TCG. Acceleration is an explicit caller choice;
    # this project does not enable or acquire any privileged iPadOS facility.
    args = [
        "qemu-system-aarch64",
        "-M", "virt",
        "-cpu", "max,pauth-impdef=on",
        "-smp", str(cpus),
        "-m", f"{memory_mib}M",
        "-display", "none",
        "-serial", "stdio",
        "-device", "usb-ehci,id=usb-bus",
        "-device", "usb-tablet,bus=usb-bus.0",
        "-device", "usb-mouse,bus=usb-bus.0",
        "-device", "usb-kbd,bus=usb-bus.0",
        "-device", "virtio-serial",
        "-device", "virtio-rng-pci",
    ]

    boot_mode = data.get("bootMode", "kernel-initrd")
    if boot_mode == "kernel-initrd":
        args.extend([
            "-kernel", bundle_file(bundle_dir, data["kernel"]),
            "-initrd", bundle_file(bundle_dir, data["initrd"]),
            "-append", data.get(
                "kernelArgs",
                "console=ttyAMA0 earlycon=pl011,mmio32,0x09000000 rootwait rw",
            ),
        ])
        disks = [
            {"id": "android-system", "path": data["systemImage"], "format": "raw"},
            {"id": "android-vendor", "path": data["vendorImage"], "format": "raw"},
            {"id": "android-userdata", "path": data["userdataImage"], "format": "raw"},
        ]
    elif boot_mode == "uefi":
        firmware = bundle_file(bundle_dir, data["firmware"])
        if data.get("firmwareCode"):
            args.extend(["-drive", f"if=pflash,format=raw,readonly=on,unit=0,file={bundle_file(bundle_dir, data['firmwareCode'])}"])
        firmware_format = data.get("firmwareFormat", "raw")
        args.extend(["-drive", f"if=pflash,format={firmware_format},unit=1,file={firmware}"])
        disks = data["disks"]
    else:
        raise ValueError(f"unsupported boot mode: {boot_mode}")

    for disk in disks:
        disk_id = disk["id"]
        args.extend([
            "-drive",
            f"if=none,format={disk.get('format', 'raw')},file={bundle_file(bundle_dir, disk['path'])},id={disk_id}",
            "-device",
            f"virtio-blk-pci,drive={disk_id}",
        ])

    graphics = data.get("graphics", {})
    if graphics.get("device") == "virtio-gpu":
        args.extend(["-device", "virtio-gpu-pci"])

    network = data.get("network", {})
    if network.get("device") == "virtio-net" and network.get("mode", "user") == "user":
        args.extend(["-netdev", "user,id=android-net", "-device", "virtio-net-pci,netdev=android-net"])

    if acceleration == "tcg-threaded":
        args.extend(["-accel", "tcg,tb-size=1024,thread=multi"])
    elif acceleration == "none":
        args.extend(["-accel", "tcg,tb-size=1024,thread=single"])
    elif acceleration != "default":
        raise ValueError(f"unsupported acceleration mode: {acceleration}")

    return args


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--memory-mib", type=int, default=4096)
    parser.add_argument("--cpus", type=int, default=4)
    parser.add_argument(
        "--acceleration",
        choices=("default", "tcg-threaded", "none"),
        default="default",
        help="Choose only the QEMU userspace acceleration argument; no privileged iPadOS setup is performed.",
    )
    parser.add_argument("--format", choices=("json", "shell"), default="json")
    args = parser.parse_args()

    if args.memory_mib < 512 or args.memory_mib > 16384:
        parser.error("--memory-mib must be between 512 and 16384")
    if args.cpus < 1 or args.cpus > 8:
        parser.error("--cpus must be between 1 and 8")

    try:
        qemu_args = generate_args(args.manifest, args.memory_mib, args.cpus, args.acceleration)
    except (OSError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.format == "shell":
        print(" ".join(shlex.quote(value) for value in qemu_args))
    else:
        print(json.dumps(qemu_args, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
