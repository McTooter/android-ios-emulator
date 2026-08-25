# Prototype Status

## Implemented

The current scaffold provides a SwiftUI iPadOS library interface for multiple APK entries, multi-file import, private APK storage, per-app profile records, isolated storage-directory identifiers, launch/pause/stop controls, and configurable memory, CPU-thread, frame-rate, resolution, graphics-backend, and execution-mode settings.

A portable C ABI and C++ implementation provide the lifecycle boundary for a future emulator backend. The current backend is intentionally a transparent stub that reports `Android runtime core is not linked yet`; it does not claim to execute APKs.

## Validation

The C++ core and lifecycle smoke test build successfully with CMake and Clang in the Linux sandbox:

```text
core smoke test passed: Stub only: link a licensed Android/QEMU runtime backend
```

The iPadOS SwiftUI target cannot be compiled in this Linux sandbox because Apple’s Xcode and iPadOS SDK are not available here. Build and device-test the Swift sources on a Mac.

## Feasibility conclusion

The user’s M1 iPad Air is a credible target for a serious emulator. Apple lists the device with an M1 chip, an 8-core CPU, an 8-core GPU, and 8GB of RAM [1]. Apple’s Metal documentation describes low-overhead GPU access suitable for the display and graphics translation layer [2]. UTM demonstrates that a QEMU-based VM host can be adapted to iOS/iPadOS and documents separate interpreter and accelerated execution paths [3] [4].

Arbitrary APK support remains a large systems project. A real implementation must supply an ARM64 Android guest or compatibility runtime, ART/DEX execution, Android framework services, package installation, virtual storage, graphics/input/audio/network devices, and app-specific compatibility work. A filename is not sufficient to identify an Android package; the guest package manager must parse the APK manifest and install it inside the guest.

Apple documents that iPadOS third-party apps are sandboxed, entitlements are digitally signed, and executable+writable memory is tightly controlled by an Apple-only dynamic-code-signing entitlement [5]. This scaffold therefore exposes acceleration as a configuration hook only and does not modify entitlements, bypass code signing, or escape the sandbox.

## References

[1]: https://support.apple.com/en-us/111887 "iPad Air (5th generation) - Tech Specs"
[2]: https://developer.apple.com/metal/ "Metal Overview"
[3]: https://github.com/utmapp/UTM "UTM source repository"
[4]: https://docs.getutm.app/installation/ios/ "UTM iOS documentation"
[5]: https://support.apple.com/en-sg/guide/security/sec15bfe098e/web "Security of runtime process in iOS, iPadOS and visionOS"
