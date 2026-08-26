import Foundation

enum RuntimeCapabilityStatus: String, CaseIterable, Identifiable {
    case available = "Available"
    case externalSetup = "External setup required"
    case unavailable = "Unavailable"
    case unverified = "Not verified"

    var id: String { rawValue }
}

struct RuntimeCapabilities: Equatable {
    let jit: RuntimeCapabilityStatus
    let memoryEntitlement: RuntimeCapabilityStatus
    let maxGuestMemoryMB: Int
    let note: String

    /// Conservative state used until a real backend reports applied capabilities.
    /// This method deliberately does not inspect private APIs or activate anything.
    static let conservative = RuntimeCapabilities(
        jit: .externalSetup,
        memoryEntitlement: .externalSetup,
        maxGuestMemoryMB: 2048,
        note: "Capabilities come from the user’s signed environment; this app does not activate or modify them."
    )
}

enum PerformancePreset: String, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case lowLatency = "Low latency"
    case batterySaver = "Battery saver"
    case custom = "Custom"

    var id: String { rawValue }

    var profile: RuntimeProfile {
        switch self {
        case .balanced:
            return RuntimeProfile(
                memoryMB: 2048,
                cpuThreads: 4,
                resolutionScale: 1.0,
                frameRateLimit: 60,
                graphicsBackend: .metalTranslation,
                executionMode: .interpreter
            )
        case .lowLatency:
            return RuntimeProfile(
                memoryMB: 3072,
                cpuThreads: 6,
                resolutionScale: 0.85,
                frameRateLimit: 60,
                graphicsBackend: .metalTranslation,
                executionMode: .accelerated
            )
        case .batterySaver:
            return RuntimeProfile(
                memoryMB: 1536,
                cpuThreads: 2,
                resolutionScale: 0.70,
                frameRateLimit: 30,
                graphicsBackend: .software,
                executionMode: .interpreter
            )
        case .custom:
            return RuntimeProfile()
        }
    }
}

extension RuntimeProfile {
    var performancePreset: PerformancePreset {
        for preset in PerformancePreset.allCases where preset != .custom {
            if self == preset.profile { return preset }
        }
        return .custom
    }

    mutating func apply(_ preset: PerformancePreset) {
        guard preset != .custom else { return }
        self = preset.profile
    }

    /// Clamps requested values before they reach a future guest backend.
    /// It changes only the in-memory request passed to the backend; it does not
    /// grant memory, enable JIT, or modify iPadOS provisioning.
    func clamped(maxMemoryMB: Int) -> RuntimeProfile {
        var copy = self
        copy.memoryMB = min(max(memoryMB, 512), max(512, maxMemoryMB))
        copy.cpuThreads = min(max(cpuThreads, 1), 8)
        copy.resolutionScale = min(max(resolutionScale, 0.5), 1.0)
        copy.frameRateLimit = min(max(frameRateLimit, 30), 120)
        return copy
    }
}
