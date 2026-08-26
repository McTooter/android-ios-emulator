import Foundation
import Combine

struct GuestManifest: Decodable, Equatable {
    let formatVersion: Int
    let guestName: String
    let androidApiLevel: Int
    let architecture: String
    let machine: String
    let bootMode: String?
    let firmware: String?
    let firmwareFormat: String?
    let disks: [Disk]?

    struct Disk: Decodable, Equatable {
        let id: String
        let path: String
        let format: String?
    }
}

enum GuestConfigurationError: LocalizedError {
    case notUtmBundle
    case missingManifest
    case invalidManifest(String)
    case unsupportedGuest(String)
    case inaccessibleGuest

    var errorDescription: String? {
        switch self {
        case .notUtmBundle:
            return "The selected item is not a .utm directory."
        case .missingManifest:
            return "The guest bundle does not contain manifest.final.json or manifest.json."
        case .invalidManifest(let reason):
            return "The guest manifest is invalid: \(reason)"
        case .unsupportedGuest(let reason):
            return "This guest is not supported by the initial Android runtime: \(reason)"
        case .inaccessibleGuest:
            return "The guest bundle is no longer accessible. Re-import it from Files."
        }
    }
}

/// Stores only a security-scoped bookmark and manifest metadata. Guest images stay
/// outside the repository and are never copied into the application source tree.
@MainActor
final class GuestStore: ObservableObject {
    @Published private(set) var guestURL: URL?
    @Published private(set) var manifest: GuestManifest?
    @Published private(set) var statusMessage = "No external Android guest selected"

    private let bookmarkKey = "AndroidRuntime.ExternalGuestBookmark"
    private let manifestKey = "AndroidRuntime.ExternalGuestManifest"

    init() {
        restore()
    }

    func importGuest(from url: URL) throws {
        guard url.pathExtension.lowercased() == "utm" else {
            throw GuestConfigurationError.notUtmBundle
        }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let resolvedURL = url.resolvingSymlinksInPath()
        let parsed = try Self.validateBundle(at: resolvedURL)
        let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        if let encoded = try? JSONEncoder().encode(parsed) {
            UserDefaults.standard.set(encoded, forKey: manifestKey)
        }
        guestURL = url
        manifest = parsed
        statusMessage = "Guest ready: \(parsed.guestName)"
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: manifestKey)
        guestURL = nil
        manifest = nil
        statusMessage = "No external Android guest selected"
    }

    /// Prepare an isolated writable guest package for one APK profile. The first
    /// implementation uses a full package copy as a correctness-first fallback;
    /// it never mutates the user-selected base bundle. QEMU backing-file overlays
    /// can replace this copy path after the on-device image-tool contract is tested.
    func profileGuestURL(for profileID: UUID) throws -> URL {
        guard let baseURL = guestURL else {
            throw GuestConfigurationError.inaccessibleGuest
        }
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let profiles = support.appendingPathComponent("AndroidRuntime/Profiles", isDirectory: true)
        try FileManager.default.createDirectory(at: profiles, withIntermediateDirectories: true)
        let destination = profiles.appendingPathComponent(profileID.uuidString).appendingPathExtension("utm")
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try Self.validateBundle(at: destination)
            return destination
        }
        let scoped = baseURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                baseURL.stopAccessingSecurityScopedResource()
            }
        }
        try FileManager.default.copyItem(at: baseURL, to: destination)
        _ = try Self.validateBundle(at: destination)
        return destination
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            statusMessage = "Guest bookmark needs to be re-imported"
            return
        }
        do {
            let parsed = try Self.validateBundle(at: url)
            guestURL = url
            manifest = parsed
            statusMessage = "Guest ready: \(parsed.guestName)"
            if stale, let refreshed = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    static func validateBundle(at bundleURL: URL) throws -> GuestManifest {
        guard bundleURL.pathExtension.lowercased() == "utm" else {
            throw GuestConfigurationError.notUtmBundle
        }
        let candidates = [
            bundleURL.appendingPathComponent("manifest.final.json"),
            bundleURL.appendingPathComponent("manifest.json")
        ]
        guard let manifestURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw GuestConfigurationError.missingManifest
        }
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw GuestConfigurationError.invalidManifest(error.localizedDescription)
        }
        let parsed: GuestManifest
        do {
            parsed = try JSONDecoder().decode(GuestManifest.self, from: data)
        } catch {
            throw GuestConfigurationError.invalidManifest(error.localizedDescription)
        }
        guard parsed.formatVersion >= 1 else {
            throw GuestConfigurationError.invalidManifest("formatVersion must be positive")
        }
        guard parsed.androidApiLevel > 0 else {
            throw GuestConfigurationError.invalidManifest("androidApiLevel must be positive")
        }
        guard parsed.architecture == "arm64-v8a" else {
            throw GuestConfigurationError.unsupportedGuest("architecture must be arm64-v8a")
        }
        guard parsed.machine == "virt" else {
            throw GuestConfigurationError.unsupportedGuest("machine must be virt")
        }
        let bootMode = parsed.bootMode ?? "kernel-initrd"
        guard bootMode == "uefi" || bootMode == "kernel-initrd" else {
            throw GuestConfigurationError.invalidManifest("bootMode must be uefi or kernel-initrd")
        }
        if bootMode == "uefi" {
            guard let firmware = parsed.firmware, !firmware.isEmpty else {
                throw GuestConfigurationError.invalidManifest("UEFI guests require firmware")
            }
            guard parsed.firmwareFormat == nil || parsed.firmwareFormat == "raw" || parsed.firmwareFormat == "qcow2" else {
                throw GuestConfigurationError.invalidManifest("firmwareFormat must be raw or qcow2")
            }
            guard let disks = parsed.disks, !disks.isEmpty else {
                throw GuestConfigurationError.invalidManifest("UEFI guests require at least one disk")
            }
            try validateRelativePath(firmware, label: "firmware", bundleURL: bundleURL)
            var ids = Set<String>()
            for disk in disks {
                guard !disk.id.isEmpty else {
                    throw GuestConfigurationError.invalidManifest("disk id must not be empty")
                }
                guard ids.insert(disk.id).inserted else {
                    throw GuestConfigurationError.invalidManifest("duplicate disk id: \(disk.id)")
                }
                guard disk.format == nil || disk.format == "raw" || disk.format == "qcow2" else {
                    throw GuestConfigurationError.invalidManifest("disk format must be raw or qcow2")
                }
                try validateRelativePath(disk.path, label: "disk \(disk.id)", bundleURL: bundleURL)
            }
        }
        return parsed
    }

    private static func validateRelativePath(_ value: String, label: String, bundleURL: URL) throws {
        guard !value.isEmpty else {
            throw GuestConfigurationError.invalidManifest("\(label) path must not be empty")
        }
        let candidate = bundleURL.appendingPathComponent(value).standardizedFileURL
        let root = bundleURL.standardizedFileURL
        guard candidate.path == root.path || candidate.path.hasPrefix(root.path + "/") else {
            throw GuestConfigurationError.invalidManifest("\(label) must remain inside the .utm bundle")
        }
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw GuestConfigurationError.invalidManifest("missing guest file for \(label): \(value)")
        }
    }
}
