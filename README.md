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

## Next engineering milestones

1. Replace `EmulatorCore` with an approved, buildable ARM64 runtime backend.
2. Boot a minimal Android guest with a known-good ARM64 kernel and system image.
3. Add APK installation through Android’s package manager and validate a simple open-source test APK.
4. Add Metal-backed display output, touch/mouse/keyboard input, audio, networking, and per-app data isolation.
5. Benchmark interpreter and accelerated configurations on the M1 iPad and document app compatibility.
