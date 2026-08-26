# Android iOS Runtime Prototype

A research scaffold for a developer-signed iPadOS app that presents a library of legally obtained Android APKs and launches them through an Android-compatible runtime core.

## Current status

This repository contains the **multi-app library and runtime integration boundary** plus guest-validation tooling. It is not currently capable of running APKs on iPadOS: the iPad adapter is still a transparent stub, the UTM/QEMU iOS archive has not been verified, and Android guest ADB/APK execution remains unproven. The repository does not include guest images or proprietary applications.

The scaffold is designed around the architecture used by projects such as [UTM](https://github.com/utmapp/UTM): a native iPadOS shell controls a separate emulator core through a narrow interface. The shell can import APK files, display metadata, maintain per-app profiles, and report runtime state. The core interface is intentionally replaceable so a licensed QEMU/AOSP-based implementation can be integrated later.

## Target

The initial target is an iPad Air (5th generation) running iPadOS 17.4.1. Apple lists this device with an M1 chip, an 8-core CPU, an 8-core GPU, and 8GB of RAM. The first compatibility target is ARM64 Android applications. The UI is designed for multiple apps, each with isolated virtual storage and runtime settings.

## Design

| Component | Responsibility | Initial implementation |
| --- | --- | --- |
| `iPadApp` | SwiftUI library, APK import, profiles, lifecycle controls | Implemented scaffold |
| `Core` | Stable C ABI for runtime start/stop/status and APK mounting | Implemented stub |
| Android guest/runtime | ART, system services, package manager, Linux device model | Future integration |
| Graphics bridge | Android GLES/Vulkan surface to Metal-backed rendering | Future integration |
| Profile store | Per-package storage, settings, save-state metadata | Implemented local model |

## Safe scope

The project does not modify entitlements, implement code-signing bypasses, defeat sandboxing, or provide instructions for unauthorized distribution. Any accelerated execution mode is exposed as a configuration choice and must be supplied by the user’s own lawful developer-signed environment.

## Build prerequisites

A real iPadOS build requires macOS, Xcode, an Apple signing identity, and a connected or registered iPad. The Linux sandbox used to prepare this scaffold does not include Xcode or Apple SDKs, so compilation and device testing must be performed on a Mac.

## Repository and first functional milestone

The public GitHub repository is available at https://github.com/McTooter/android-ios-emulator. It tracks UTM as an upstream submodule under `vendor/UTM` and includes a macOS GitHub Actions workflow. The custom shell build job succeeds and produces an unsigned shell payload; the separate UTM dependency/archive job remains unverified. The shell payload is not a generic UTM IPA and neither artifact should be called a working Android APK runtime.

Run `scripts/build-utm-ios.sh` on a Mac with Xcode to perform the same UTM build locally. The resulting archive or payload must be signed with the user’s own Apple development identity before installation. The repository’s custom SwiftUI target remains the multi-APK library shell that will later host the Android-specific guest integration.

## Android guest input contract

The future Android boot backend accepts a local guest directory described by `Config/guest-manifest.example.json`. The initial contract expects an ARM64 `virt` machine and named kernel, initrd, system, vendor, and userdata images. Validate a supplied bundle before booting with:

```sh
python3 tools/validate_guest.py /path/to/guest/manifest.json
```

The validator checks manifest structure, architecture, machine type, and that all named files remain inside the guest directory. It does not prove that an image is bootable and does not execute any guest code.

For a validated bundle, `tools/qemu_args.py` emits a deterministic, non-executing QEMU ARM64 argument list. It is an integration aid only: it does not launch QEMU, download guest images, enable JIT, change entitlements, or bypass iPadOS security controls.

```sh
python3 tools/qemu_args.py /path/to/guest/manifest.json --memory-mib 4096 --cpus 4 --acceleration tcg-threaded --format shell
```

The generator models either the legacy kernel/initrd form or the real UEFI/qcow2 UTM bundle form, with a QEMU `virt` machine, virtio block devices, optional virtio GPU, user-mode virtio networking, and explicit TCG choices. The project’s current reference guest is the public LineageOS `virtio_arm64only` UTM build from [android-lineage-qemu](https://github.com/jqssun/android-lineage-qemu), kept outside this repository and accepted only as a locally authorized input. Its official UTM guide requires ANGLE (OpenGL) for the Android UI; ANGLE (Metal) can leave the UI invisible after boot.

The guest has now been statically validated and partially boot-tested under Linux QEMU: with UEFI, `-cpu max`, and copy-on-write disks it reached Android framework initialization and boot animation without the earlier kernel panic. ADB remained offline before the bounded test ended, so no package-manager install or APK launch has been demonstrated.

The macOS workflow caches the exact `sysroot-iOS-arm64` output and retains dependency logs on failure. Public hosted macOS runners do execute the jobs, and the custom shell build succeeds. The UTM dependency build has reached real Mesa/QEMU configuration but remains long-running and has successively exposed concrete dependency/configuration issues; the latest run was canceled after a bounded window rather than being left unattended. A Mac with Xcode remains the most predictable path for a complete UTM archive build, but the user currently has no Mac.

## Next engineering milestones

1. Replace `EmulatorCore` with an approved, buildable ARM64 runtime backend.
2. Boot a minimal Android guest with a known-good ARM64 kernel and system image.
3. Add APK installation through Android’s package manager and validate a simple open-source test APK.
4. Add Metal-backed display output, touch/mouse/keyboard input, audio, networking, and per-app data isolation.
5. Benchmark interpreter and accelerated configurations on the M1 iPad and document app compatibility.
