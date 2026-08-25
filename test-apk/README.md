# AndroidRuntime Test APK

This is a small original Android application owned by this project. It has one launcher activity, uses no Google Play Services, contains no proprietary assets, and includes no native libraries. It is intended to validate the future guest package-manager install and launcher path without depending on a third-party APK.

Build it from this directory with `./gradlew :app:assembleDebug` after installing a compatible Android SDK and JDK. The resulting debug APK is under `app/build/outputs/apk/debug/` and can be inspected with the repository’s APK tool.

A successful build or static inspection does **not** prove that UTM, QEMU, Android ART, or the iPadOS frontend can boot and launch it. That requires a real ARM64 Android guest and an actual install/launch test.
