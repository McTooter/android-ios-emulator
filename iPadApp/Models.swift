import Foundation
import Combine

struct RuntimeProfile: Codable, Hashable {
    var memoryMB: Int = 2048
    var cpuThreads: Int = 4
    var resolutionScale: Double = 1.0
    var frameRateLimit: Int = 60
    var graphicsBackend: GraphicsBackend = .metalTranslation
    var executionMode: ExecutionMode = .interpreter

    enum GraphicsBackend: String, Codable, CaseIterable, Identifiable {
        case metalTranslation = "Metal translation"
        case software = "Software fallback"

        var id: String { rawValue }
    }

    enum ExecutionMode: String, Codable, CaseIterable, Identifiable {
        case interpreter = "Interpreter-safe"
        case accelerated = "Accelerated (external setup)"

        var id: String { rawValue }
    }
}

struct AndroidPackage: Identifiable, Codable, Hashable {
    let id: UUID
    var packageName: String
    var displayName: String
    var apkFileName: String
    var importedAt: Date
    var profile: RuntimeProfile
    var storageDirectoryName: String

    init(
        id: UUID = UUID(),
        packageName: String,
        displayName: String,
        apkFileName: String,
        importedAt: Date = .now,
        profile: RuntimeProfile = .init()
    ) {
        self.id = id
        self.packageName = packageName
        self.displayName = displayName
        self.apkFileName = apkFileName
        self.importedAt = importedAt
        self.profile = profile
        self.storageDirectoryName = id.uuidString
    }
}

enum RuntimeState: Equatable {
    case stopped
    case starting
    case running
    case paused
    case failed(String)

    var title: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting"
        case .running: return "Running"
        case .paused: return "Paused"
        case .failed(let message): return "Failed: \(message)"
        }
    }
}

@MainActor
final class PackageStore: ObservableObject {
    @Published private(set) var packages: [AndroidPackage] = []

    private let fileManager = FileManager.default
    private let catalogFileName = "package-catalog.json"

    init() {
        load()
    }

    func addAPK(from url: URL) throws {
        let packagesURL = try packagesDirectory()
        let destination = packagesURL.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: url, to: destination)

        let baseName = url.deletingPathExtension().lastPathComponent
        let entry = AndroidPackage(
            packageName: "local.\(baseName.lowercased().replacingOccurrences(of: " ", with: "_"))",
            displayName: baseName.isEmpty ? "Imported Android app" : baseName,
            apkFileName: destination.lastPathComponent
        )
        packages.append(entry)
        save()
    }

    func remove(_ package: AndroidPackage) throws {
        let packagesURL = try packagesDirectory()
        let apkURL = packagesURL.appendingPathComponent(package.apkFileName)
        if fileManager.fileExists(atPath: apkURL.path) {
            try fileManager.removeItem(at: apkURL)
        }
        packages.removeAll { $0.id == package.id }
        save()
    }

    func update(_ package: AndroidPackage) {
        guard let index = packages.firstIndex(where: { $0.id == package.id }) else { return }
        packages[index] = package
        save()
    }

    func apkURL(for package: AndroidPackage) throws -> URL {
        try packagesDirectory().appendingPathComponent(package.apkFileName)
    }

    private func packagesDirectory() throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("AndroidRuntime/Packages", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func catalogURL() -> URL? {
        try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("AndroidRuntime/").appendingPathComponent(catalogFileName)
    }

    private func load() {
        guard let url = catalogURL(), let data = try? Data(contentsOf: url) else { return }
        packages = (try? JSONDecoder().decode([AndroidPackage].self, from: data)) ?? []
    }

    private func save() {
        guard let url = catalogURL() else { return }
        try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(packages) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
