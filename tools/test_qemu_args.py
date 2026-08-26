#!/usr/bin/env python3
"""Tests for the non-executing ARM64 QEMU argument generator."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from qemu_args import generate_args
from validate_guest import validate


class QemuArgsTests(unittest.TestCase):
    def make_bundle(self) -> tuple[Path, dict]:
        root = Path(tempfile.mkdtemp(prefix="android-guest-test-"))
        data = root / "Data"
        data.mkdir()
        for filename in ("efi_vars.fd", "vda.qcow2", "vdb.qcow2"):
            (data / filename).write_bytes(b"fixture")
        manifest = {
            "formatVersion": 2,
            "guestName": "test",
            "androidApiLevel": 35,
            "architecture": "arm64-v8a",
            "machine": "virt",
            "bootMode": "uefi",
            "firmware": "Data/efi_vars.fd",
            "firmwareFormat": "raw",
            "disks": [
                {"id": "vda", "path": "Data/vda.qcow2", "format": "qcow2"},
                {"id": "vdb", "path": "Data/vdb.qcow2", "format": "qcow2"},
            ],
            "graphics": {"device": "virtio-gpu", "renderer": "angle-opengl"},
            "network": {"device": "virtio-net", "mode": "user"},
        }
        manifest_path = root / "manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        return manifest_path, manifest

    def test_uefi_manifest_and_custom_forwards(self) -> None:
        manifest_path, _ = self.make_bundle()
        self.assertEqual(validate(manifest_path), [])
        args = generate_args(
            manifest_path,
            memory_mib=2048,
            cpus=2,
            acceleration="tcg-threaded",
            adb_host_port=15555,
            fastboot_host_port=15554,
        )
        self.assertIn("-M", args)
        self.assertIn("virt", args)
        self.assertIn("-cpu", args)
        self.assertIn("max,pauth-impdef=on", args)
        self.assertIn("-accel", args)
        netdev = args[args.index("-netdev") + 1]
        self.assertIn("hostfwd=tcp:127.0.0.1:15555-:5555", netdev)
        self.assertIn("hostfwd=tcp:127.0.0.1:15554-:5554", netdev)

    def test_manifest_rejects_escape_path(self) -> None:
        manifest_path, manifest = self.make_bundle()
        manifest["firmware"] = "../outside.fd"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        errors = validate(manifest_path)
        self.assertTrue(any("must remain inside" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
