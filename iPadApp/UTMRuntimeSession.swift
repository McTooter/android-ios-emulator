#if ANDROID_RUNTIME_UTM
import Foundation
import SwiftUI

/// Swift-facing ownership of one UTM QEMU session. This type intentionally owns
/// UTM display/input objects rather than exposing UIKit or Metal through the C ABI.
@MainActor
final class UTMRuntimeSession: NSObject, ObservableObject {
    let vm: UTMQemuVirtualMachine
    let session: VMSessionState

    init(guestURL: URL, profile: RuntimeProfile) throws {
        guard FileManager.default.fileExists(atPath: guestURL.path) else {
            throw GuestConfigurationError.inaccessibleGuest
        }
        guard let loaded = try UTMQemuConfiguration.load(from: guestURL) as? UTMQemuConfiguration else {
            throw GuestConfigurationError.invalidManifest("UTM configuration could not be loaded")
        }
        guard loaded.system.architecture == .aarch64 else {
            throw GuestConfigurationError.unsupportedGuest("the UTM configuration is not ARM64")
        }
        guard loaded.system.target.rawValue == QEMUTarget_aarch64.virt.rawValue else {
            throw GuestConfigurationError.unsupportedGuest("the QEMU machine must be virt")
        }
        self.vm = try UTMQemuVirtualMachine(
            packageUrl: guestURL,
            configuration: loaded,
            isShortcut: true
        )
        self.session = VMSessionState(for: vm)
        super.init()
        apply(profile)
    }

    func apply(_ profile: RuntimeProfile) {
        let safe = profile.clamped(maxMemoryMB: RuntimeCapabilities.conservative.maxGuestMemoryMB)
        vm.config.system.memorySize = safe.memoryMB
        vm.config.system.cpuCount = safe.cpuThreads
        vm.config.system.isForceMulticore = safe.cpuThreads > 1
        vm.config.system.cpu = QEMUCPU_aarch64.max
        vm.config.system.cpuFlagsAdd = []
        vm.config.system.cpuFlagsRemove = []
        vm.config.qemu.isDisposable = false
    }

    func start() async throws {
        try await vm.start(options: [])
    }

    func pause() async throws {
        try await vm.pause()
    }

    func resume() async throws {
        try await vm.resume()
    }

    func stop() async throws {
        try await vm.stop(usingMethod: .force)
    }

    func kill() async throws {
        try await vm.stop(usingMethod: .kill)
    }
}

/// Small SwiftUI bridge around UTM’s existing iOS Metal display controller.
struct AndroidRuntimeGuestView: View {
    @ObservedObject var session: VMSessionState
    @State private var windowState: VMWindowState

    init(session: VMSessionState) {
        self.session = session
        let windowID = session.newWindow().windowID
        _windowState = State(initialValue: VMWindowState(id: windowID))
    }

    var body: some View {
        Group {
            if let device = windowState.device {
                VMDisplayHostedView(
                    vm: session.vm,
                    device: device,
                    state: $windowState
                )
                .environmentObject(session)
            } else {
                ProgressView("Waiting for Android display…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            session.registerWindow(windowState.id)
            assignDeviceIfAvailable()
        }
        .onChange(of: session.devices) { _, _ in
            assignDeviceIfAvailable()
        }
        .onDisappear {
            session.removeWindow(windowState.id)
        }
    }

    private func assignDeviceIfAvailable() {
        guard windowState.device == nil else { return }
        if let mapped = session.windowDeviceMap[windowState.id] {
            windowState.device = mapped
        } else if let first = session.devices.first {
            windowState.device = first
        }
    }
}
#endif
