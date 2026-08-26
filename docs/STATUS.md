# Prototype Status

**Updated:** 2026-08-26

## Executive status

The repository is a public, audited research prototype for an Android-on-iPad architecture. The SwiftUI iPadOS library shell and a separate upstream UTM/QEMU iOS archive now build successfully in public macOS CI, and the portable C++ lifecycle boundary, guest-manifest validator, QEMU argument generator, and original test APK pass local checks. The project does **not** yet provide a combined working Android emulator IPA: the current iPad adapter is a transparent stub, the UTM archive is generic upstream UTM rather than this shell’s linked backend, Android guest ADB is not reachable, and no APK has been installed or launched inside a guest.

## Confirmed implementation

The SwiftUI shell supports multiple legally obtained APK imports, private app storage, catalog records, per-app runtime profiles, isolated directory identifiers, and launch/pause/stop controls. It now also displays conservative JIT and memory-capability status, provides Balanced/Low-latency/Battery-saver presets, and clamps requested guest memory before passing it to the backend. These are transparent configuration and reporting features; they do not activate JIT or modify provisioning. The portable C ABI and C++ implementation provide the lifecycle boundary for a future runtime backend and intentionally report that no Android runtime core is linked.

The guest tooling supports both a legacy kernel/initrd contract and the external UEFI/qcow2 ARM64 UTM bundle. Validation enforces ARM64, the `virt` machine, supported disk formats, and strict path containment. The QEMU argument generator emits a non-executing configuration with `max,pauth-impdef=on`, threaded TCG, UEFI pflash, VirtIO disks, VirtIO GPU/network, USB input, serial/RNG, and local ADB/fastboot forwards.

## Verification record

| Area | Result | Evidence |
| --- | --- | --- |
| Native C++ core | **Pass** | CMake configure/build and lifecycle smoke test pass; smoke test identifies the backend as a stub. |
| Original Android test APK | **Pass** | Gradle 8.7 and Android SDK 35 build; package `com.mctooter.androidruntimetest`; no native libraries; arm64-compatible; current rebuilt artifact is local only. |
| Guest manifest | **Pass** | External public LineageOS UTM bundle validates as ARM64/UEFI/qcow2 and remains outside the repository. |
| QEMU configuration | **Pass** | Unit tests and deterministic argument generation pass; generation does not start QEMU. |
| SwiftUI iPad shell | **Pass in hosted CI** | Public workflow build job produced an unsigned custom shell archive/payload in run `32946819499`; this is not the UTM emulator. |
| UTM/QEMU iOS archive | **Pass as separate generic artifact** | Run `32960303538` built and uploaded `UTM-QEMU-iOS-unsigned` after using the matching public sysroot, current Xcode selection, and the runtime asset compatibility patch. It is upstream UTM and is not linked to the custom APK library shell. |
| Android guest boot | **Partial** | Linux QEMU with copy-on-write overlays reached Android framework services and boot animation using `max,pauth-impdef=on`; this is not iPadOS execution proof. |
| ADB/APK execution | **Fail/not reachable** | `adb devices` showed no device; the harness failed with `127.0.0.1:5555` connection refused. No install, launcher resolution, process check, or APK launch completed. |

## Latest build state

The repository’s latest synchronized code commit is `6b7b107`, with this status correction committed afterward. The decisive workflow was run `32960303538`: both the custom shell job and the UTM/QEMU iOS milestone job completed successfully. It uploaded `AndroidRuntime-iOS-unsigned` and `UTM-QEMU-iOS-unsigned` artifacts. The UTM artifact is a separate generic UTM build, not a combined AndroidRuntime app. The faster route uses the matching upstream UTM sysroot artifact `8927678456` (source revision `8e4de50817e76a83d6840212311627a78dd4f8b2`) with verified digest `37eedf9a42989af3e2526ddbf11c1281f12b295708c20169c46ca0063f014b0d`.

Artifact links: [custom shell artifact](https://github.com/McTooter/android-ios-emulator/actions/runs/32960303538/artifacts/9603608457) and [UTM/QEMU artifact](https://github.com/McTooter/android-ios-emulator/actions/runs/32960303538/artifacts/9603726828).

The public CI route remains free. A successful custom shell archive must not be described as a working Android emulator or as a generic UTM IPA. The custom shell and UTM archive are separate products: the former has the multi-APK library UI, while the latter can host virtual machines but does not yet contain this project’s shell integration or a verified Android guest/APK run.

## Guest and legal boundaries

The external ARM64 LineageOS UTM release used for research was downloaded as an uncommitted local input. Its UEFI variables and qcow2 disks are not included in this repository. The project’s original test APK is lawful project-owned smoke-test content; proprietary APKs, game assets, unauthorized downloads, and system images are not included.

The iPadOS code does not add JIT activation, alter entitlements, bypass code signing, jailbreak devices, defeat sandbox restrictions, or provide unauthorized acquisition or signing instructions. SideStore can install a user-signed IPA, but it cannot compile this source or turn an unsigned archive into a working signed application by itself. A real device test still requires an appropriately signed build and an iPad-side input/rendering check.

## Remaining gates

The next useful engineering step is not another blind CI loop. The new settings layer is ready for a real backend, but the UTM build still must complete dependency compilation and produce a verifiable `.xcarchive`/payload. Separately, an interactive graphical guest test must make the public LineageOS guest show ADB as `device`; only then should the original test APK be installed and launched. After those gates, the project still needs the actual SwiftUI-to-UTM integration, display/input bridge, per-profile guest storage, capability reporting from the installed build, and two-profile testing.

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
