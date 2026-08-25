# Building the Prototype

## What can be built now

The `Core` directory builds on Linux, macOS, and other CMake-capable hosts as a static C++ library. Its smoke test verifies the lifecycle ABI and intentionally reports that no Android backend is linked.

```sh
cd Core
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/AndroidRuntimeCoreSmokeTest
```

## iPadOS build

A real iPadOS application must be built on a Mac with Xcode and the iPadOS SDK. Create an iOS App target using SwiftUI, add the files in `iPadApp/`, add `Core/EmulatorCore.h` as a bridging header, and add `Core/EmulatorCore.cpp` to the target or link the compiled static library. The target should be configured for arm64 iOS devices and tested on the iPad Air (5th generation).

The current Swift UI is deliberately usable before the core exists: it imports `.apk` files into the app’s private storage, creates catalog records, stores per-app settings, and displays explicit “Android runtime core is not linked yet” status when Launch is pressed.

## Backend integration order

1. Add a licensed or otherwise compatible QEMU/AOSP backend as a separate build target.
2. Boot a minimal ARM64 Android guest from a local image and expose framebuffer, input, storage, and lifecycle callbacks through `EmulatorCore.h`.
3. Replace placeholder package names by parsing each APK’s manifest and installing it through the guest package manager.
4. Add guest networking, audio, sensors, graphics translation, and Android framework services incrementally.
5. Benchmark interpreter and accelerated configurations on the physical iPad.

The guest manifest tooling also includes a deterministic, non-executing QEMU argument generator:

```sh
python3 tools/qemu_args.py /path/to/guest/manifest.json --memory-mib 4096 --cpus 4 --acceleration tcg-threaded --format shell
```

It only emits arguments and never launches QEMU, downloads images, enables JIT, changes entitlements, or bypasses iPadOS security controls. Its current `virt` layout is experimental until a real LineageOS `virtio_arm64only` or AOSP-derived ARM64 guest is built and boot-tested.

The macOS workflow now caches the exact `vendor/UTM/sysroot-iOS-arm64` directory and uploads the dependency log on failure. On 2026-08-25, GitHub rejected both the UTM job and a separate short macOS 14 runner probe before any step executed, with no runner name or downloadable log. This prevents a hosted archive verification at present; it does not demonstrate a successful UTM or Android build.

Do not copy proprietary Android system images or application assets into this repository without the appropriate rights. Do not alter entitlements or code-signing metadata as part of the build.
