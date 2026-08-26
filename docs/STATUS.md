# Prototype Status

**Updated:** 2026-08-26

## Executive status

The repository is a public, audited research prototype for an Android-on-iPad architecture. The SwiftUI library, external guest importer, profile-isolated guest preparation, and a conditional UTM/QEMU session/display bridge are now implemented in source. The existing standalone shell and separate generic UTM/QEMU archive build successfully in public macOS CI. The first combined-target workflow definition is pushed, but its macOS runs currently end in runner `startup_failure` before any job starts, so no integrated archive has yet been compiled or tested.

## Confirmed implementation

The SwiftUI shell supports multiple legally obtained APK imports, private app storage, catalog records, per-app runtime profiles, isolated directory identifiers, and launch/pause/stop controls. It also imports and validates a user-supplied `.utm` guest through a security-scoped bookmark, prepares a separate writable guest package for each profile, displays conservative JIT and memory-capability status, provides performance presets, and clamps requested guest memory. In the adapted UTM target, `UTMRuntimeSession` owns `UTMQemuVirtualMachine` and `VMSessionState`, while `AndroidRuntimeGuestView` hosts UTM’s live iOS display controller. These are source-level integration paths; they are not yet hardware-verified. No JIT activation or provisioning modification is included.

The guest tooling supports both a legacy kernel/initrd contract and the external UEFI/qcow2 ARM64 UTM bundle. Validation enforces ARM64, the `virt` machine, supported disk formats, and strict path containment. The QEMU argument generator emits a non-executing configuration with `max,pauth-impdef=on`, threaded TCG, UEFI pflash, VirtIO disks, VirtIO GPU/network, USB input, serial/RNG, and local ADB/fastboot forwards.

## Verification record

| Area | Result | Evidence |
| --- | --- | --- |
| Native C++ core | **Pass** | CMake configure/build and lifecycle smoke test pass; smoke test identifies the backend as a stub. |
| Original Android test APK | **Pass** | Gradle 8.7 and Android SDK 35 build; package `com.mctooter.androidruntimetest`; no native libraries; arm64-compatible; current rebuilt artifact is local only. |
| Guest manifest | **Pass** | External public LineageOS UTM bundle validates as ARM64/UEFI/qcow2 and remains outside the repository. |
| QEMU configuration | **Pass** | Unit tests and deterministic argument generation pass; generation does not start QEMU. |
| SwiftUI iPad shell | **Pass in hosted CI** | Run `32960303538` produced the unsigned custom shell archive/payload; this remains a shell-only artifact. |
| UTM/QEMU iOS archive | **Pass as separate generic artifact** | Run `32960303538` built and uploaded the generic upstream UTM/QEMU archive using the matching public sysroot and runtime asset compatibility patch. |
| Combined AndroidRuntime/UTM target | **Source patch committed; build unverified** | Commit `50a38be` adds the UTM target patch and conditional session/display bridge. Runs `32985105287` and `32985506499` ended with macOS runner `startup_failure` and no job logs before compilation. |
| External guest importer/profile isolation | **Local source checks pass** | `GuestConfiguration.swift` validates ARM64/virt guests and prepares a per-profile package copy without mutating the selected base. On-device overlay efficiency is still pending. |
| Android guest boot | **Partial** | Linux QEMU with copy-on-write overlays reached Android framework services and boot animation using `max,pauth-impdef=on`; this is not iPadOS execution proof. |
| ADB/APK execution | **Fail/not reachable** | `adb devices` showed no device; the harness failed with `127.0.0.1:5555` connection refused. No install, launcher resolution, process check, or APK launch completed. |

## Latest build state

The repository’s latest synchronized code commit is `082b1ee`. The last successful macOS build remains run `32960303538`, which produced separate shell and generic UTM/QEMU artifacts. The integration commits are `50a38be` and `082b1ee`; their push-triggered runs `32985105287` and `32985506499` failed at runner startup with no compilation logs. A manual run `32985087337` remained queued without starting. The integrated workflow uses the matching upstream UTM sysroot artifact `8927678456` (source revision `8e4de50817e76a83d6840212311627a78dd4f8b2`) with verified digest `37eedf9a42989af3e2526ddbf11c1281f12b295708c20169c46ca0063f014b0d`.

Artifact links: [custom shell artifact](https://github.com/McTooter/android-ios-emulator/actions/runs/32960303538/artifacts/9603608457) and [UTM/QEMU artifact](https://github.com/McTooter/android-ios-emulator/actions/runs/32960303538/artifacts/9603726828).

The public CI route remains free. A successful custom shell archive must not be described as a working Android emulator or as a generic UTM IPA. The custom shell and UTM archive are separate products: the former has the multi-APK library UI, while the latter can host virtual machines but does not yet contain this project’s shell integration or a verified Android guest/APK run.

## Guest and legal boundaries

The external ARM64 LineageOS UTM release used for research was downloaded as an uncommitted local input. Its UEFI variables and qcow2 disks are not included in this repository. The project’s original test APK is lawful project-owned smoke-test content; proprietary APKs, game assets, unauthorized downloads, and system images are not included.

The iPadOS code does not add JIT activation, alter entitlements, bypass code signing, jailbreak devices, defeat sandbox restrictions, or provide unauthorized acquisition or signing instructions. SideStore can install a user-signed IPA, but it cannot compile this source or turn an unsigned archive into a working signed application by itself. A real device test still requires an appropriately signed build and an iPad-side input/rendering check.

## Remaining gates

The next useful engineering gates are: obtain a macOS runner start for the integrated target; compile and inspect one `AndroidRuntime.app` containing UTM’s ARM64 QEMU framework/resources; import the external LineageOS guest; reach a visible Android UI; make ADB report `device`; install and launch the original smoke APK; then verify two profile copies remain isolated. The current profile isolation path uses a full package copy for correctness and should later be replaced by a tested qcow2 backing-chain overlay where the on-device image-tool contract permits it.

Universal arbitrary-APK compatibility is not expected. Google Play Services, DRM, ABI requirements, graphics behavior, permissions, server availability, and application-specific assumptions can prevent individual apps from working.

## References

[1]: https://support.apple.com/en-us/111887 "iPad Air (5th generation) - Tech Specs"

[2]: https://github.com/utmapp/UTM "UTM source repository"

[3]: https://docs.getutm.app/installation/ios/ "UTM iOS documentation"

[4]: https://support.apple.com/en-sg/guide/security/sec15bfe098e/web "Security of runtime process in iOS, iPadOS and visionOS"

[5]: https://wiki.lineageos.org/utm-vm-on-apple-silicon-mac "LineageOS UTM guide"

[6]: https://github.com/jqssun/android-lineage-qemu "LineageOS for QEMU Virtual Machines"

[7]: https://formulae.brew.sh/formula/libclc "Homebrew libclc formula"

[8]: https://formulae.brew.sh/formula/spirv-tools "Homebrew spirv-tools formula"
