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

## Android Guest Image Research

LineageOS documents building an image for a libvirt QEMU virtual machine and notes that `virtio_*` targets are community-maintained, not built by LineageOS build servers, and have known graphics/video limitations: https://wiki.lineageos.org/libvirt-qemu

AOSP documents Cuttlefish as a configurable virtual Android device that runs locally on Linux x86 and ARM64 machines or remotely through cloud offerings. Cuttlefish is a useful guest/image reference, but its documented host assumptions are Linux-based and it is not a drop-in iPadOS component: https://source.android.com/docs/devices/cuttlefish

The project should therefore accept a user-supplied, legally obtained ARM64 guest bundle rather than downloading proprietary system images or pretending that an ordinary Android emulator image can boot unchanged on iPadOS. The guest configuration layer can validate required files, architecture, and image metadata before invoking UTM/QEMU.
