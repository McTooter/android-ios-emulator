# CI Diagnostic — 2026-08-25

The checkout is synchronized with `origin/master` at commit `5852e61` (`Document UTM build findings`), with no local modifications. The pinned UTM submodule is `8e4de50817e76a83d6840212311627a78dd4f8b2`.

The latest push run `32881915121` and manual run `32882125047` both concluded `failure`. The manual run started at 18:09:42Z and both jobs ended within approximately three seconds with zero steps, no runner name, and no downloadable logs. Repository Actions are enabled and allow all actions. This indicates a GitHub runner-service/capacity rejection rather than a shell-step failure; the API does not expose a more specific message and the unauthenticated web page is unavailable.

The prior runner-backed run `32870609069` used a GitHub-hosted runner and its custom `build` job succeeded. The companion UTM job used a runner but failed before the dependency build completed. Its available failure log reports the older workflow invoking `./scripts/build_dependencies.sh -p ios -a arm64` and failing the environment check with `'six' not found in your Python 3 installation.` This predates the current virtualenv setup, which must still be verified on a fresh runner.

Only unsigned custom-app artifacts are currently present. There is no UTM/QEMU archive artifact. The current UTM script creates `sysroot-iOS-arm64` because `PLATFORM_FAMILY_PREFIX` is `iOS`, so cache paths must use that exact case. The upstream workflow caches sysroots keyed by platform/architecture plus dependency script and patches; the project workflow currently rebuilds from scratch and does not cache or upload the dependency log on failure.

No guest image, Android boot, APK installation, or device launch has been verified. Do not claim arbitrary APK execution.


Official runner-image documentation confirms that `macos-15` is an active GitHub-hosted image and currently includes Xcode 16.4 as the default plus Xcode 26.x installations, while `macos-14` is also documented but is scheduled for deprecation later in 2026. GitHub’s public status API reports the Actions component as operational. The repeated current-run failures therefore remain consistent with a repository/account-level runner allocation or quota rejection rather than a missing `macos-15` label; changing labels is not yet justified without a runner-backed diagnostic.


A dedicated manual `macos-14` probe run `32882953347` also failed in about three seconds with zero steps, no runner name, and no logs. GitHub Actions status was operational, so this is now confirmed as a hosted-runner allocation/account limitation affecting this repository at the present time, not a UTM script or macOS 15 label issue. No further macOS workflow runs should be launched until that allocation issue is cleared; repeated attempts would only waste Actions capacity.


Guest-path research: LineageOS publishes an official libvirt/QEMU build guide with `virtio_arm64` and `virtio_arm64only` targets, but explicitly notes that these targets are maintained by individual maintainers, are not built by LineageOS build servers, and are not guaranteed to work with a generic ARM64 `virt` guest without additional configuration. The `virtio_arm64only` target is recommended for ARMv9 hardware, while the project’s M1 target is ARM64 and still requires a compatible guest build. AOSP Cuttlefish is an open-source reference virtual device with ARM64 builds, but its official launch flow depends on host virtualization/KVM and a Cuttlefish runtime, so it is not automatically a self-contained QEMU bundle suitable for embedding in an iPad app. The current lawful input contract should therefore remain user-supplied, checksummed ARM64 guest artifacts; the first practical implementation target is a dedicated LineageOS `virtio_arm64only` or AOSP-derived guest validated on a desktop QEMU host before attempting iPad integration.


The original test APK was built locally with official Gradle 8.7 and Android SDK platform/build tools. `:app:assembleDebug` succeeded. Static inspection reported 8,653 bytes, `classes.dex` and `classes2.dex`, no native libraries, a binary manifest, and `supportsInitialTarget: true`. SHA-256: `87c42dcd87cfebc417f73bc5fb1e4a780219efe9b0877d15fd666581b051fa30`. This is only a build/static milestone; no Android guest or APK launch has been verified.


Guest validation milestone: the public `jqssun/android-lineage-qemu` release `v2026.08.22` provides an ARM64-only UTM VM archive containing `LineageOS_on_arm64.utm/Data/efi_vars.fd`, `vda.qcow2`, `vdb.qcow2`, and `config.plist`. The archive SHA-256 is `ed7ec8030d094597d40371bc02ac66f5e4fff532bf70e6af50c108657dde2c00`. After local extraction, the new format-2 manifest validator accepted the real 2.2 GiB UTM bundle, and the generator emitted the expected UEFI, qcow2 virtio-disk, virtio-GPU, and virtio-network arguments. This is static/configuration validation only; QEMU is not installed in the sandbox, and the guest has not booted or installed/launched an APK.


The downloaded public release’s own build script confirms the `virtio_arm64only` UTM VM is produced from LineageOS 23.2 and is intended for ARM64-only hosts. A real Linux QEMU attempt reached the Android kernel, mounted the LineageOS partitions, formatted the blank metadata partition, loaded several modules, and then panicked while loading `virt_wifi.ko` in `dlkm_loader_mainline`. QEMU terminated after 90 seconds and ADB port 5555 never opened. This is the first actual guest-boot evidence, but it is a failed boot, not an APK execution result. The original release disk was not used directly after this attempt; future retries must use qcow2 overlays to avoid mutating downloaded input.


## 2026-08-26 authentication recovery and current CI state

The GitHub CLI initially reported both configured tokens invalid, causing HTTPS pushes to fail. Running `manus-config config load --search github` refreshed the enabled GitHub connector snapshot. `gh auth status` then reported the `McTooter` account active, and the four preserved local commits pushed successfully; `master` and `origin/master` now point to `51bc51b`.

The push-triggered runs for commit `51bc51b` were `32922520019` (Android Test APK) and `32922519966` (iPadOS Build). Their jobs all completed in approximately three seconds with `runner_name` empty, zero steps, and no downloadable logs. Repository Actions permissions are enabled and allow all actions. This is a separate hosted-runner allocation or account-capacity problem, not a Git authentication problem. The billing endpoint returned 403 because the current token lacks the billing permission, so the owner must inspect Actions usage/spending limits in GitHub Settings or provide a self-hosted Mac runner for the UTM archive build.
