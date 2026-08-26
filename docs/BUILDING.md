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
python3 tools/qemu_args.py /path/to/guest/manifest.json \
  --memory-mib 4096 --cpus 4 --acceleration tcg-threaded \
  --adb-host-port 5555 --fastboot-host-port 5554 --format shell
```

It only emits arguments and never launches QEMU, downloads images, enables JIT, changes entitlements, or bypasses iPadOS security controls. Its current `virt` layout accepts the real UEFI/qcow2 form used by the public LineageOS `virtio_arm64only` UTM guest. The official LineageOS UTM guide requires ANGLE (OpenGL) for that guest; ANGLE (Metal) can leave the Android UI invisible after boot.

A Linux QEMU test with UEFI, `-cpu max`, TCG, and copy-on-write disks reached Android framework initialization and boot animation without the earlier `virt_wifi.ko` panic. The forwarded ADB endpoint stayed offline before cleanup, so this is not yet a package-install or APK-launch test.

The macOS workflow now caches the exact `vendor/UTM/sysroot-iOS-arm64` directory and uploads the dependency log on failure. GitHub currently rejects both the UTM job and a separate short macOS 14 runner probe before any step executes, with no runner name or downloadable log. This prevents hosted archive verification at present; it is an account/runner-capacity problem rather than a source-code failure. No paid service is required for the local checks below.

Run the no-cost local verification wrapper from the repository root. It runs the native checks, builds and inspects the original test APK when Gradle and an Android SDK are available, and accepts an optional guest manifest. It never launches a guest or changes iPadOS security settings:

```sh
ANDROID_HOME=/path/to/android-sdk \
ANDROID_SDK_ROOT=/path/to/android-sdk \
GRADLE_BIN=/path/to/gradle \
./scripts/verify-local.sh
```

For the extracted UTM bundle, point the wrapper at the manifest inside the bundle, not at an outer manifest whose `Data/` paths resolve elsewhere:

```sh
ANDROID_GUEST_MANIFEST=/path/to/LineageOS_on_arm64.utm/manifest.json \
./scripts/verify-local.sh
```

Once a guest exposes ADB, build the original test APK and run the host-side installation/launch check:

```sh
ANDROID_HOME=/path/to/android-sdk /path/to/gradle -p test-apk :app:assembleDebug
python3 tools/test_guest_apk.py test-apk/app/build/outputs/apk/debug/app-debug.apk \
  --package com.mctooter.androidruntimetest --serial 127.0.0.1:5555
```

The harness waits for ADB, installs the APK, confirms the installed package path, resolves its explicit MAIN/LAUNCHER activity, starts it, and checks for the package process. It fails rather than reporting success when the guest is offline or the process is absent. The public LineageOS release documents that an offline guest may require booting LineageOS Recovery, opening Advanced, choosing Mount/unmount system, and selecting Enable ADB; the procedure is recorded in `docs/guest-adb-finding.md`.

Do not copy proprietary Android system images or application assets into this repository without the appropriate rights. Do not alter entitlements or code-signing metadata as part of the build.
