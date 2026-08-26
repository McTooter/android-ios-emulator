# No-Cost Mac and iPad Handoff

This guide avoids paid GitHub Actions usage. The Linux sandbox can validate the portable core, guest tooling, and original test APK. An already-owned Mac is still required for Xcode, the iPadOS SDK, and final device signing; the project does not require a paid build service.

## 1. Clone the private repository

```sh
git clone --recurse-submodules https://github.com/McTooter/android-ios-emulator.git
cd android-ios-emulator
```

If the repository was cloned previously, synchronize the submodule before building:

```sh
git pull --rebase
git submodule update --init --recursive
```

## 2. Run the free local checks

Install only the tools already available on the Mac or obtained from their official open-source distributors: CMake, Python 3, Gradle, and an Android SDK for the test APK.

```sh
ANDROID_HOME=/path/to/android-sdk \
ANDROID_SDK_ROOT=/path/to/android-sdk \
GRADLE_BIN=/path/to/gradle \
./scripts/verify-local.sh
```

For a lawful external UTM guest, point to the manifest inside the extracted bundle:

```sh
ANDROID_GUEST_MANIFEST=/path/to/LineageOS_on_arm64.utm/manifest.json \
./scripts/verify-local.sh
```

The script does not download system images, enable JIT, modify entitlements, or start an emulator automatically.

## 3. Produce the unsigned UTM iOS payload locally

From the repository root on macOS with Xcode selected:

```sh
./scripts/build-utm-ios.sh artifacts
```

The script delegates dependency and archive construction to the pinned UTM submodule, then creates `artifacts/UTM-unsigned-payload.zip`. Inspect the archive before any signing operation:

```sh
unzip -l artifacts/UTM-unsigned-payload.zip | sed -n '1,80p'
```

The source does not contain an Apple signing identity, provisioning profile, private key, or entitlement-escalation logic.

## 4. Build the custom library shell

```sh
xcodegen generate
xcodebuild -project AndroidRuntime.xcodeproj \
  -scheme AndroidRuntime \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath artifacts/AndroidRuntime.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  archive
```

The current shell can import APKs, maintain per-app profiles, and report the unlinked backend honestly. It is not yet the completed Android runtime.

## 5. Supply the lawful guest and enable ADB

Use only an Android guest image that the user is authorized to use. For the tested public LineageOS ARM64 UTM guest, keep the bundle outside the Git repository and use the `virt` machine, UEFI/qcow2 disks, VirtIO devices, and ANGLE/OpenGL renderer.

If the guest starts but ADB is offline, follow the public guest instructions in the Recovery UI: **Advanced → Mount/unmount system → Enable ADB**. Recovery ADB may also require the documented host-key authorization conditions. The project’s `tools/test_guest_apk.py` harness intentionally fails when ADB is offline.

## 6. Sign and test on the iPad

Use the user’s own lawful Apple signing and sideloading process. Do not add certificates or private keys to the repository. Install the signed app on the iPad Air 5 and record whether the shell opens, the guest renders, touch input works, and the guest remains stable.

The final APK test is:

```sh
python3 tools/test_guest_apk.py /path/to/android-runtime-test-debug.apk \
  --package com.mctooter.androidruntimetest \
  --serial 127.0.0.1:5555
```

Success requires ADB state `device`, successful package installation, explicit launcher resolution, activity start, and a live package process. Until those conditions are observed on the actual guest and iPad, the project must not be described as a working arbitrary-APK emulator.

## Current boundary

The code and free local checks are ready for the next integration step, but the native iPad adapter still needs the UTM/QEMU backend wired into its lifecycle and rendering interfaces. The repository therefore distinguishes verified tooling and Linux guest boot evidence from unverified iPad execution.
