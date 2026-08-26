import Foundation
import Combine

@MainActor
final class RuntimeController: ObservableObject {
    @Published private(set) var states: [UUID: RuntimeState] = [:]
    @Published private(set) var activePackageID: UUID?
    @Published private(set) var capabilities = RuntimeCapabilities.conservative
#if ANDROID_RUNTIME_UTM
    @Published private(set) var activeSession: UTMRuntimeSession?
#endif

    private let store: PackageStore
    private let guestStore: GuestStore
#if ANDROID_RUNTIME_UTM
    private let core: UTMCoreAdapter
#else
    private let core: EmulatorCoreAdapter
#endif

    init(store: PackageStore, guestStore: GuestStore) {
        self.store = store
        self.guestStore = guestStore
#if ANDROID_RUNTIME_UTM
        self.core = UTMCoreAdapter(guestStore: guestStore)
#else
        self.core = EmulatorCoreAdapter()
#endif
    }

    func state(for package: AndroidPackage) -> RuntimeState {
        states[package.id] ?? .stopped
    }

    func launch(_ package: AndroidPackage) {
        stopAll(except: package.id)
        states[package.id] = .starting
        activePackageID = package.id

#if ANDROID_RUNTIME_UTM
        if activePackageID == package.id, let session = activeSession, state(for: package) == .paused {
            Task { @MainActor [weak self] in
                do {
                    try await session.resume()
                    self?.states[package.id] = .running
                } catch {
                    self?.states[package.id] = .failed(error.localizedDescription)
                }
            }
            return
        }
        guard guestStore.guestURL != nil else {
            states[package.id] = .failed("Import a lawful ARM64 LineageOS .utm guest first")
            activePackageID = nil
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let session = try self.core.makeSession(profile: package.profile)
                self.activeSession = session
                try await session.start()
                self.states[package.id] = .running
            } catch {
                self.activeSession = nil
                self.states[package.id] = .failed(error.localizedDescription)
            }
        }
#else
        do {
            let apkURL = try store.apkURL(for: package)
            let result = core.start(
                apkURL: apkURL,
                profile: package.profile.clamped(maxMemoryMB: capabilities.maxGuestMemoryMB),
                storageDirectoryName: package.storageDirectoryName
            )
            states[package.id] = result
        } catch {
            states[package.id] = .failed(error.localizedDescription)
        }
#endif
    }

    func pause(_ package: AndroidPackage) {
#if ANDROID_RUNTIME_UTM
        guard activePackageID == package.id, let session = activeSession else { return }
        Task { @MainActor [weak self] in
            do {
                try await session.pause()
                self?.states[package.id] = .paused
            } catch {
                self?.states[package.id] = .failed(error.localizedDescription)
            }
        }
#else
        guard state(for: package) == .running else { return }
        states[package.id] = core.pause()
#endif
    }

    func resume(_ package: AndroidPackage) {
#if ANDROID_RUNTIME_UTM
        guard activePackageID == package.id, let session = activeSession else { return }
        Task { @MainActor [weak self] in
            do {
                try await session.resume()
                self?.states[package.id] = .running
            } catch {
                self?.states[package.id] = .failed(error.localizedDescription)
            }
        }
#else
        guard state(for: package) == .paused else { return }
        states[package.id] = core.resume()
#endif
    }

    func stop(_ package: AndroidPackage) {
#if ANDROID_RUNTIME_UTM
        guard activePackageID == package.id, let session = activeSession else {
            states[package.id] = .stopped
            return
        }
        Task { @MainActor [weak self] in
            try? await session.stop()
            self?.activeSession = nil
            self?.states[package.id] = .stopped
            if self?.activePackageID == package.id {
                self?.activePackageID = nil
            }
        }
#else
        core.stop()
        states[package.id] = .stopped
        if activePackageID == package.id {
            activePackageID = nil
        }
#endif
    }

    func stopAll(except packageID: UUID? = nil) {
#if ANDROID_RUNTIME_UTM
        if let activeSession, activePackageID != packageID {
            Task { @MainActor [weak self] in
                try? await activeSession.stop()
                self?.activeSession = nil
            }
        }
#else
        if packageID == nil {
            core.stop()
        }
#endif
        for package in store.packages where package.id != packageID {
            if state(for: package) != .stopped {
                states[package.id] = .stopped
            }
        }
        if packageID == nil {
            activePackageID = nil
        }
    }
}

#if ANDROID_RUNTIME_UTM
@MainActor
final class UTMCoreAdapter {
    private let guestStore: GuestStore

    init(guestStore: GuestStore) {
        self.guestStore = guestStore
    }

    func makeSession(profile: RuntimeProfile) throws -> UTMRuntimeSession {
        guard let guestURL = guestStore.guestURL else {
            throw GuestConfigurationError.inaccessibleGuest
        }
        return try UTMRuntimeSession(guestURL: guestURL, profile: profile)
    }
}
#else
/// Stable Swift-facing boundary for the standalone shell. It intentionally does
/// not claim to execute Android until the UTM-backed target is built and tested.
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
        _ = profile
        _ = storageDirectoryName
        isRunning = false
        return .failed("Android runtime core is not linked yet")
    }

    func pause() -> RuntimeState {
        isRunning = false
        return .paused
    }

    func resume() -> RuntimeState {
        isRunning = true
        return .running
    }

    func stop() {
        isRunning = false
    }
}
#endif
