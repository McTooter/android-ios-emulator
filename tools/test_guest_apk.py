#!/usr/bin/env python3
"""Install and launch a lawful test APK on a reachable Android QEMU guest.

This is a host-side verification harness. It does not start QEMU, enable JIT,
modify entitlements, or bypass Android/iPadOS security controls.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


def adb(serial: str, *args: str, timeout: float = 20.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", "-s", serial, *args],
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def fail(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--serial", default="127.0.0.1:5555")
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()

    if not args.apk.is_file():
        return fail(f"APK not found: {args.apk}")
    if args.timeout < 10 or args.timeout > 1800:
        return fail("--timeout must be between 10 and 1800 seconds")

    connect = subprocess.run(
        ["adb", "connect", args.serial],
        text=True,
        capture_output=True,
        timeout=20,
        check=False,
    )
    print(connect.stdout.strip() or connect.stderr.strip())

    deadline = time.monotonic() + args.timeout
    state = ""
    while time.monotonic() < deadline:
        result = adb(args.serial, "get-state")
        state = (result.stdout or result.stderr).strip()
        if state == "device":
            break
        time.sleep(2)
    else:
        return fail(f"ADB guest did not become ready; final state: {state or 'unavailable'}")

    boot = adb(args.serial, "shell", "getprop", "sys.boot_completed")
    print(f"sys.boot_completed={boot.stdout.strip()}")

    install = adb(args.serial, "install", "-r", str(args.apk), timeout=120)
    if install.returncode != 0 or "Success" not in install.stdout:
        return fail(f"APK install failed: {(install.stdout + install.stderr).strip()}")
    print(f"installed={args.package}")

    resolved = adb(args.serial, "shell", "cmd", "package", "resolve-activity", "--brief", args.package)
    if resolved.returncode != 0:
        return fail(f"launcher resolution failed: {(resolved.stdout + resolved.stderr).strip()}")
    print(f"resolved_activity={(resolved.stdout + resolved.stderr).strip()}")

    launch = adb(
        args.serial,
        "shell",
        "monkey",
        "-p",
        args.package,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
    )
    if launch.returncode != 0:
        return fail(f"launcher command failed: {(launch.stdout + launch.stderr).strip()}")
    print("launcher_command=completed")

    for _ in range(15):
        process = adb(args.serial, "shell", "pidof", args.package)
        if process.stdout.strip():
            print(f"process_pid={process.stdout.strip()}")
            print("guest_apk_install_launch=PASS")
            return 0
        time.sleep(1)

    return fail("launcher command completed but the package process was not observed")


if __name__ == "__main__":
    raise SystemExit(main())
