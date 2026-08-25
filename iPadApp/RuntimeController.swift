import Foundation
import Combine

@MainActor
final class RuntimeController: ObservableObject {
    @Published private(set) var states: [UUID: RuntimeState] = [:]
    @Published private(set) var activePackageID: UUID?

    private let store: PackageStore
    private let core = EmulatorCoreAdapter()

    init(store: PackageStore) {
        self.store = store
    }

    func state(for package: AndroidPackage) -> RuntimeState {
        states[package.id] ?? .stopped
    }

    func launch(_ package: AndroidPackage) {
        stopAll(except: package.id)
        states[package.id] = .starting
        activePackageID = package.id

        do {
            let apkURL = try store.apkURL(for: package)
            let result = core.start(
                apkURL: apkURL,
                profile: package.profile,
                storageDirectoryName: package.storageDirectoryName
            )
            states[package.id] = result
        } catch {
            states[package.id] = .failed(error.localizedDescription)
        }
    }

    func pause(_ package: AndroidPackage) {
        guard state(for: package) == .running else { return }
        states[package.id] = core.pause()
    }

    func stop(_ package: AndroidPackage) {
        core.stop()
        states[package.id] = .stopped
        if activePackageID == package.id {
            activePackageID = nil
        }
    }

    func stopAll(except packageID: UUID? = nil) {
        for package in store.packages where package.id != packageID {
            if state(for: package) != .stopped {
                states[package.id] = .stopped
            }
        }
        if packageID == nil {
            core.stop()
            activePackageID = nil
        }
    }
}

/// Stable Swift-facing boundary. Replace this adapter with the C/Rust runtime bridge
/// after an Android guest and graphics backend are available.
final class EmulatorCoreAdapter {
    private(set) var isRunning = false

    func start(
        apkURL: URL,
        profile: RuntimeProfile,
        storageDirectoryName: String
    ) -> RuntimeState {
        guard FileManager.default.fileExists(atPath: apkURL.path) else {
            return .failed("APK file is missing")
        }

        // The current repository is a shell-only prototype. This explicit failure
        // prevents the UI from implying that an APK was executed when no runtime
        // backend has been linked.
        _ = profile
        _ = storageDirectoryName
        isRunning = false
        return .failed("Android runtime core is not linked yet")
    }

    func pause() -> RuntimeState {
        isRunning = false
        return .paused
    }

    func stop() {
        isRunning = false
    }
}
