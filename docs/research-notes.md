# Research Notes

UTM reference: https://github.com/utmapp/UTM
UTM iOS documentation: https://docs.getutm.app/installation/ios/
Apple runtime security: https://support.apple.com/en-sg/guide/security/sec15bfe098e/web
Apple Metal: https://developer.apple.com/metal/
Apple Virtualization: https://developer.apple.com/documentation/virtualization
AOSP ART: https://source.android.com/docs/core/runtime
QEMU ARM system emulation: https://www.qemu.org/docs/master/system/target-arm.html

UTM’s iOS development notes describe building iOS with an arm64 target, separating the normal iOS build from the slower UTM SE build, and re-signing artifacts for device use. They document that the stock signed build requires a development certificate and a provisioning profile with get-task-allow, while tethered launching through a debugger is used for JIT on recent iOS versions. These are UTM-specific implementation details and are not instructions to bypass Apple security.

The UTM repository also exposes separate platform/UI, QEMU helper, launcher, and render-server components. Its recent source tree includes iOS platform code, QEMU integration, renderer components, and configuration directories. For this project, the useful pattern is a thin iPadOS UI/control layer over a separately testable emulator core, with rendering and lifecycle operations isolated behind explicit interfaces.

The prototype in this repository is intentionally a host-side architecture and UI scaffold. It does not include QEMU, AOSP, ART, proprietary Android system images, or any JIT/entitlement modification. A full arbitrary-APK runtime requires those components and must be built and signed using Xcode on a Mac.
