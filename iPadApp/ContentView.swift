import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store: PackageStore
    @StateObject private var runtime: RuntimeController
    @State private var selectedID: AndroidPackage.ID?
    @State private var showingImporter = false
    @State private var importError: String?

    init() {
        let packageStore = PackageStore()
        _store = StateObject(wrappedValue: packageStore)
        _runtime = StateObject(wrappedValue: RuntimeController(store: packageStore))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                Section("Android library") {
                    if store.packages.isEmpty {
                        ContentUnavailableView(
                            "No APKs imported",
                            systemImage: "shippingbox",
                            description: Text("Import legally obtained APK files to create isolated app profiles.")
                        )
                    } else {
                        ForEach(store.packages) { package in
                            PackageRow(
                                package: package,
                                state: runtime.state(for: package)
                            )
                            .tag(package.id)
                            .contextMenu {
                                Button(role: .destructive) {
                                    remove(package)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Android Runtime")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import APK", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let selectedID, let package = store.packages.first(where: { $0.id == selectedID }) {
                PackageDetailView(
                    package: package,
                    state: runtime.state(for: package),
                    onUpdate: { store.update($0) },
                    onApplyPreset: { preset in
                        var updated = package
                        updated.profile.apply(preset)
                        store.update(updated)
                    },
                    capabilities: runtime.capabilities,
                    onLaunch: { runtime.launch(package) },
                    onPause: { runtime.pause(package) },
                    onStop: { runtime.stop(package) }
                )
            } else {
                ContentUnavailableView(
                    "Select an app",
                    systemImage: "apps.iphone",
                    description: Text("Each imported APK receives its own profile and virtual storage directory.")
                )
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [UTType(filenameExtension: "apk") ?? .data],
            allowsMultipleSelection: true,
            onCompletion: handleImport
        )
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Unknown error")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw CocoaError(.fileReadNoPermission)
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    try store.addAPK(from: url)
                } catch {
                    importError = error.localizedDescription
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                importError = error.localizedDescription
            }
        }
    }

    private func remove(_ package: AndroidPackage) {
        do {
            runtime.stop(package)
            try store.remove(package)
            if selectedID == package.id {
                selectedID = nil
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct PackageRow: View {
    let package: AndroidPackage
    let state: RuntimeState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "android.logo")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(package.displayName)
                    .font(.headline)
                Text(package.packageName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        switch state {
        case .running: return .green
        case .starting: return .orange
        case .failed: return .red
        default: return .secondary
        }
    }
}

private struct PackageDetailView: View {
    @State private var package: AndroidPackage
    let state: RuntimeState
    let onUpdate: (AndroidPackage) -> Void
    let onApplyPreset: (PerformancePreset) -> Void
    let capabilities: RuntimeCapabilities
    let onLaunch: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    init(
        package: AndroidPackage,
        state: RuntimeState,
        onUpdate: @escaping (AndroidPackage) -> Void,
        onApplyPreset: @escaping (PerformancePreset) -> Void,
        capabilities: RuntimeCapabilities,
        onLaunch: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        _package = State(initialValue: package)
        self.state = state
        self.onUpdate = onUpdate
        self.onApplyPreset = onApplyPreset
        self.capabilities = capabilities
        self.onLaunch = onLaunch
        self.onPause = onPause
        self.onStop = onStop
    }

    var body: some View {
        Form {
            Section {
                Label(package.displayName, systemImage: "android.logo")
                    .font(.title2.weight(.semibold))
                LabeledContent("Package", value: package.packageName)
                LabeledContent("APK", value: package.apkFileName)
                LabeledContent("Runtime", value: state.title)
            }

            Section("External capabilities") {
                LabeledContent("JIT", value: capabilities.jit.rawValue)
                LabeledContent("Memory entitlement", value: capabilities.memoryEntitlement.rawValue)
                Text(capabilities.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Runtime controls") {
                Picker("Performance profile", selection: Binding(
                    get: { package.profile.performancePreset },
                    set: { preset in
                        guard preset != .custom else { return }
                        package.profile.apply(preset)
                        onApplyPreset(preset)
                    }
                )) {
                    ForEach(PerformancePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }

                Picker("Execution mode", selection: $package.profile.executionMode) {
                    ForEach(RuntimeProfile.ExecutionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Picker("Graphics", selection: $package.profile.graphicsBackend) {
                    ForEach(RuntimeProfile.GraphicsBackend.allCases) { backend in
                        Text(backend.rawValue).tag(backend)
                    }
                }
                Stepper("Memory: \(package.profile.memoryMB) MB", value: $package.profile.memoryMB, in: 512...max(512, capabilities.maxGuestMemoryMB), step: 256)
                Stepper("CPU threads: \(package.profile.cpuThreads)", value: $package.profile.cpuThreads, in: 1...8)
                Stepper("Frame limit: \(package.profile.frameRateLimit) FPS", value: $package.profile.frameRateLimit, in: 30...120, step: 30)
                Slider(value: $package.profile.resolutionScale, in: 0.5...1.0, step: 0.05) {
                    Text("Resolution: \(package.profile.resolutionScale, specifier: "%.2f")x")
                }
                .onChange(of: package.profile) { _, _ in onUpdate(package) }
            }

            Section {
                HStack {
                    switch state {
                    case .running:
                        Button("Pause", action: onPause)
                        Button("Stop", role: .destructive, action: onStop)
                    case .paused:
                        Button("Resume", action: onLaunch)
                        Button("Stop", role: .destructive, action: onStop)
                    default:
                        Button("Launch", action: onLaunch)
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Text("Core: scaffold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(package.displayName)
        .onDisappear { onUpdate(package) }
    }
}
