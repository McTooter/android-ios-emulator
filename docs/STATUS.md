# Prototype Status

## Confirmed in the repository

The project contains a SwiftUI iPadOS library shell for multiple legally obtained APK files. It supports multi-file import, private APK storage, per-app profile records, isolated storage-directory identifiers, launch/pause/stop controls, and configurable memory, CPU-thread, frame-rate, resolution, graphics-backend, and execution-mode settings.

The portable C ABI and C++ implementation provide a stable lifecycle boundary for a future emulator backend. The current iPad adapter is intentionally transparent: it reports that the Android runtime core is not linked and does not claim to execute APKs. A host-side `test_guest_apk.py` harness now exists for the later install, launcher-resolution, and process-observation test once ADB is reachable.

The guest manifest and QEMU argument tools now support both the earlier kernel/initrd layout and the real UEFI/qcow2 UTM layout used by the public ARM64-only LineageOS QEMU project. Generated arguments include the documented `virt` machine, `max,pauth-impdef=on` CPU model, threaded TCG option, UEFI pflash, VirtIO disks, VirtIO GPU/network, USB input, VirtIO serial/RNG, and local TCP forwards for ADB and fastboot.

## Verified locally

The native C++ core and lifecycle smoke test build successfully with CMake and Clang:

```text
core smoke test passed: Stub only: link a licensed Android/QEMU runtime backend
```

The original project test APK builds with Gradle 8.7 and Android SDK 35. Static inspection reports package `com.mctooter.androidruntimetest`, label `AndroidRuntime Test`, launcher activity `com.mctooter.androidruntimetest.MainActivity`, two DEX files, no native libraries, and compatibility with the initial arm64 target. Its current SHA-256 is `87c42dcd87cfebc417f73bc5fb1e4a780219efe9b0877d15fd666581b051fa30`.

The public `jqssun/android-lineage-qemu` release `v2026.08.22` was downloaded only as an external, uncommitted guest input. Its ARM64-only UTM archive contains an Apple UTM bundle with UEFI variables, a 5 GiB virtual `vda.qcow2`, a sparse 16 GiB `vdb.qcow2`, and a QEMU configuration using the `virt` machine, AArch64, two CPUs, 2048 MiB RAM, and VirtIO devices. The archive SHA-256 is `ed7ec8030d094597d40371bc02ac66f5e4fff532bf70e6af50c108657dde2c00`.

A real Linux QEMU run using copy-on-write overlays and `-cpu max` reached Android framework initialization, `system_server`, graphics-service startup, `artd`, and boot animation without the first attempt’s `virt_wifi.ko` kernel panic. The first attempt with a Cortex-A72 CPU did panic while loading `virt_wifi.ko`; the supported `max,pauth-impdef=on` configuration avoided that panic. The guest’s forwarded ADB endpoint remained offline or unavailable before cleanup, so no package-manager install or APK launch has been verified.

The official LineageOS UTM guide states that this guest requires ANGLE (OpenGL) for visible Android UI; ANGLE (Metal) may leave the UI invisible after boot [6]. The example manifest therefore uses `angle-opengl`. This is a guest-specific setting and does not mean the iPad Metal rendering bridge is complete.

## Build and device status

The custom unsigned iPadOS archive job has succeeded in earlier GitHub Actions runs. The separate UTM/QEMU iOS archive job has not yet produced a verified archive because GitHub rejected macOS 15 and a separate short macOS 14 runner probe before any job step executed. The current GitHub CLI credentials have also expired, so the latest local QEMU-generator commit is two commits ahead of the remote repository and cannot be pushed until GitHub access is reauthorized.

A real iPad test still requires a Mac/Xcode signing environment and the user’s own Apple development identity and provisioning profile. The project does not add JIT, alter entitlements, bypass code signing, jailbreak the device, or defeat iPadOS sandbox restrictions.

## Not yet supported or proven

The iPad app does not currently boot an Android guest, install an APK through Android Package Manager, render Android UI, or launch an Android application. The Linux QEMU boot evidence is useful backend validation but is not proof that the iPadOS UTM build or the SwiftUI app works on the iPad. Universal arbitrary-APK compatibility is not expected: Google Play Services, DRM, server shutdown, ABI requirements, graphics behavior, permissions, and app-specific assumptions can prevent individual apps from working. Proprietary APKs and game assets must be legally obtained by the user and are not included.

## References

[1]: https://support.apple.com/en-us/111887 "iPad Air (5th generation) - Tech Specs"

[2]: https://developer.apple.com/metal/ "Metal Overview"

[3]: https://github.com/utmapp/UTM "UTM source repository"

[4]: https://docs.getutm.app/installation/ios/ "UTM iOS documentation"

[5]: https://support.apple.com/en-sg/guide/security/sec15bfe098e/web "Security of runtime process in iOS, iPadOS and visionOS"

[6]: https://wiki.lineageos.org/utm-vm-on-apple-silicon-mac "Building and installing for UTM virtual machine on Apple Silicon Mac"

[7]: https://github.com/jqssun/android-lineage-qemu "LineageOS for QEMU Virtual Machines"
