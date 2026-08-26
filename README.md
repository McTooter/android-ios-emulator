# Android iOS Runtime Prototype

A research scaffold for a developer-signed iPadOS app that presents a library of legally obtained Android APKs and launches them through an Android-compatible runtime core.

## Current status

This repository contains the **multi-app library, external guest importer, profile-isolation model, and runtime integration boundary** plus guest-validation tooling. The adapted UTM target is now wired in source to `UTMQemuVirtualMachine`, `VMSessionState`, and UTM’s iOS display controller, but the combined archive has not yet been compiled because recent GitHub macOS runner starts failed before jobs were created. Android guest ADB/APK execution remains unproven. The repository does not include guest images or proprietary applications.

The scaffold is designed around the architecture used by projects such as [UTM](https://github.com/utmapp/UTM): a native iPadOS shell controls a separate emulator core through a narrow interface. The shell can import APK files, display metadata, maintain per-app profiles, and report runtime state. The core interface is intentionally replaceable so a licensed QEMU/AOSP-based implementation can be integrated later.

## Target

The initial target is an iPad Air (5th generation) running iPadOS 17.4.1. Apple lists this device with an M1 chip, an 8-core CPU, an 8-core GPU, and 8GB of RAM. The first compatibility target is ARM64 Android applications. The UI is designed for multiple apps, each with isolated virtual storage and runtime settings.

## Design

| Component | Responsibility | Initial implementation |
| --- | --- | --- |
| `iPadApp` | SwiftUI library, APK import, profiles, lifecycle controls | Implemented scaffold |
| `Core` | Stable C ABI for portable lifecycle/status boundary | Implemented stub; UIKit/Metal stay outside the ABI |
| UTM/QEMU session | ARM64 QEMU VM lifecycle, SPICE display/input, UEFI/qcow2 guest | Source-level adapted target; archive unverified |
| Android guest/runtime | ART, system services, package manager, Linux device model | User-supplied LineageOS `.utm`; boot/APK gates pending |
| Graphics bridge | UTM `VMDisplayHostedView` and Metal-backed rendering | Source-level bridge; device test pending |
| Profile store | Per-package storage, settings, guest package preparation | Implemented full-copy isolation fallback |

## Safe scope

The project does not modify entitlements, implement code-signing bypasses, defeat sandboxing, or provide instructions for unauthorized distribution. Any accelerated execution mode is exposed as a configuration choice and must be supplied by the user’s own lawful developer-signed environment.

## Build prerequisites

A real iPadOS build requires macOS, Xcode, an Apple signing identity, and a connected or registered iPad. The Linux sandbox used to prepare this scaffold does not include Xcode or Apple SDKs, so compilation and device testing must be performed on a Mac.

## Repository and first functional milestone

The public GitHub repository is available at https://github.com/McTooter/android-ios-emulator. It tracks UTM as an upstream submodule under `vendor/UTM` and includes a macOS GitHub Actions workflow. Run `32960303538` proved the separate shell and generic UTM artifacts; commits `50a38be` and `082b1ee` add the adapted single-target integration and profile guest preparation. The integrated target still needs a successful macOS runner start and compile. No artifact should be called a working Android APK runtime until guest boot, ADB, install, launch, and device checks pass.

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

The macOS workflow caches the exact `sysroot-iOS-arm64` output and retains dependency logs on failure. The generic UTM archive succeeded in run `32960303538`, but the integrated workflow runs `32985105287` and `32985506499` ended with runner `startup_failure` before compilation; manual run `32985087337` remained queued. A Mac with Xcode remains the fallback for compiling the adapted target if hosted macOS runners remain unavailable, but the user currently has no Mac.

## Next engineering milestones

1. Obtain a macOS runner start and compile the one adapted AndroidRuntime/UTM target.
2. Import a lawful ARM64/UEFI/`virt` LineageOS `.utm` guest and verify visible display/input.
3. Add an in-process ADB transport over the guest forward, parse real APK manifests, and install/launch the smoke APK.
4. Replace the correctness-first full guest copies with tested qcow2 backing overlays where supported.
5. Benchmark interpreter and externally configured acceleration modes on the M1 iPad and document app compatibility.
