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

A real iPadOS application must be built on a Mac with Xcode and the iPadOS SDK. The standalone `project.yml` target remains a shell-only build. The integration path now applies `tools/patch_utm_androidruntime.py` to UTM’s pinned iOS target in CI, adds the custom SwiftUI/library files to the same module, disables UTM’s JIT compilation condition for this project, and keeps UTM’s QEMU frameworks, resources, package dependencies, and embed phases.

The shell imports `.apk` files into private storage and accepts a user-supplied `.utm` guest through the Files picker. The adapted UTM target uses `UTMQemuVirtualMachine`, `VMSessionState`, and `VMDisplayHostedView` for lifecycle and live display. The external guest remains outside the repository. A profile currently receives a correctness-first full package copy; qcow2 backing overlays are a later optimization after on-device image tooling is verified.

## Backend integration order

1. Build the single adapted AndroidRuntime/UTM iOS target and verify the archive contains `AndroidRuntime.app`, `qemu-aarch64-softmmu.framework`, and the QEMU resource bundle.
2. Import a lawfully obtained ARM64/UEFI/`virt` LineageOS `.utm` guest and boot it without mutating the shared base guest.
3. Confirm a visible Android display and touch/keyboard input through UTM’s existing iOS display controller.
4. Add an in-process ADB transport over the guest’s configured forward; host-side `adb` is only a diagnostic tool and is not assumed to exist inside iPadOS.
5. Parse each APK’s real manifest package/activity, install it through ADB/package-manager commands, launch it, and verify its process.
6. Verify two profile copies have independent writable state, then replace full copies with tested qcow2 backing overlays where supported.
7. Benchmark interpreter and externally configured acceleration modes on the physical iPad.

The guest manifest tooling also includes a deterministic, non-executing QEMU argument generator:

```sh
python3 tools/qemu_args.py /path/to/guest/manifest.json \
  --memory-mib 4096 --cpus 4 --acceleration tcg-threaded \
  --adb-host-port 5555 --fastboot-host-port 5554 --format shell
```

It only emits arguments and never launches QEMU, downloads images, enables JIT, changes entitlements, or bypasses iPadOS security controls. Its current `virt` layout accepts the real UEFI/qcow2 form used by the public LineageOS `virtio_arm64only` UTM guest. The official LineageOS UTM guide requires ANGLE (OpenGL) for that guest; ANGLE (Metal) can leave the Android UI invisible after boot.

A Linux QEMU test with UEFI, `-cpu max`, TCG, and copy-on-write disks reached Android framework initialization and boot animation without the earlier `virt_wifi.ko` panic. The forwarded ADB endpoint stayed offline before cleanup, so this is not yet a package-install or APK-launch test.

The macOS workflow caches the exact `vendor/UTM/sysroot-iOS-arm64` directory and uploads the dependency log on failure. Run `32960303538` proved that the generic UTM/QEMU archive route succeeds. The newer integrated workflow is committed at `082b1ee`, but its push-triggered runs `32985105287` and `32985506499` failed with runner `startup_failure` before creating jobs, while manual run `32985087337` remained queued. This is an infrastructure-startup blocker, not evidence that the integrated source compiles. No paid service is required for the local checks below.

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
