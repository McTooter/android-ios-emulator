# Android iOS Runtime Prototype

A research scaffold for a developer-signed iPadOS app that presents a library of legally obtained Android APKs and launches them through an Android-compatible runtime core.

## Current status

This repository contains the **multi-app library and runtime integration boundary** only. It does not yet contain an Android guest image, ART, QEMU, a graphics translation implementation, or an APK execution engine. Consequently, it is not currently capable of running APKs. Those components require a Mac with Xcode and substantial native systems development.

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

The private GitHub repository is available at https://github.com/McTooter/android-ios-emulator. It tracks UTM as an upstream submodule under `vendor/UTM` and includes a macOS GitHub Actions workflow. The `build-utm-milestone` job follows UTM’s documented dependency and iOS archive build sequence and uploads an unsigned UTM/QEMU iOS payload. This is the first functional emulator milestone; it is not yet the Android APK runtime.

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

The generator currently models a QEMU `virt` machine with a kernel, initrd, three raw virtio block devices, optional virtio GPU, user-mode virtio networking, and explicit TCG choices. The image layout and kernel command line remain experimental until a real LineageOS `virtio_arm64only` or AOSP-derived guest is built and boot-tested.

The repository’s macOS workflow now caches the exact `sysroot-iOS-arm64` output and retains the dependency log. As of 2026-08-25, GitHub rejects both the UTM build and a separate ten-second macOS 14 runner probe before any step starts, with no runner name or downloadable log. This is a hosted-runner allocation limitation, not evidence that UTM or Android has built successfully; a Mac with Xcode remains the reliable path for the next archive test.

## Next engineering milestones

1. Replace `EmulatorCore` with an approved, buildable ARM64 runtime backend.
2. Boot a minimal Android guest with a known-good ARM64 kernel and system image.
3. Add APK installation through Android’s package manager and validate a simple open-source test APK.
4. Add Metal-backed display output, touch/mouse/keyboard input, audio, networking, and per-app data isolation.
5. Benchmark interpreter and accelerated configurations on the M1 iPad and document app compatibility.
