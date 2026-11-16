import Foundation
import Combine

/// Owns service bindings, their live runtime state, and the polling loop.
///
/// Polling only runs while the Services pane is visible. One request per
/// binding is in flight at a time, and `refreshSeconds` is honoured per
/// binding.
final class ServicesStore: ObservableObject {
    @Published private(set) var bindings: [ServiceBinding] = []
    @Published private(set) var runtimes: [UUID: ServiceRuntime] = [:]
    @Published private(set) var memoryHistory: [UUID: [Double]] = [:]
    @Published private(set) var isPolling = false
    @Published var lastActionError: String?

    /// The Add / Edit Service page currently open, if any. It lives here so the
    /// page and its draft survive the popover closing and section switches.
    @Published private(set) var editor: ServiceEditorModel?

    private let client: ServiceClient
    private let launcher: ServiceLauncher
    private let tokenStore: ServiceTokenStoring
    private let bindingStore: ServiceBindingStore
    private let providers: [ServiceKind: ServiceProvider]

    private var pollTimer: Timer?
    private var lastPollAt: [UUID: Date] = [:]
    /// Probe requests in flight. Kept separate from `actionInFlight` so a
    /// poll never makes Start/Stop silently do nothing (and vice versa).
    private var pollInFlight: Set<UUID> = []
    private var actionInFlight: Set<UUID> = []
    /// A refresh requested while a probe was in flight, to run once it ends.
    private var pendingRefresh: Set<UUID> = []
    private let historyBuffer = HistoryBuffer(capacity: 30)

    init(
        client: ServiceClient = ServiceClient(),
        launcher: ServiceLauncher = ServiceLauncher(),
        tokenStore: ServiceTokenStoring = KeychainServiceTokenStore(),
        bindingStore: ServiceBindingStore = ServiceBindingStore()
    ) {
        self.client = client
        self.launcher = launcher
        self.tokenStore = tokenStore
        self.bindingStore = bindingStore
        self.providers = [
            .manifest: ManifestProvider(client: client, launcher: launcher),
            .launchd: LaunchdProvider(),
            .process: ProcessProvider(),
            .command: CommandProvider()
        ]

        self.bindings = bindingStore.load()
        for binding in bindings {
            runtimes[binding.id] = ServiceRuntime()
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Lookup

    func binding(for id: UUID) -> ServiceBinding? {
        bindings.first { $0.id == id }
    }

    func runtime(for id: UUID) -> ServiceRuntime {
        runtimes[id] ?? ServiceRuntime()
    }

    func history(for id: UUID) -> [Double] {
        memoryHistory[id] ?? []
    }

    private func provider(for kind: ServiceKind) -> ServiceProvider {
        providers[kind] ?? providers[.manifest]!
    }

    func hasToken(for id: UUID) -> Bool {
        tokenStore.token(for: id)?.isEmpty == false
    }

    /// The service's web panel, if it has one. Prefers the address resolved
    /// from the last status response and falls back to the manifest path so
    /// the button is available before the first poll.
    func panelURL(for id: UUID) -> URL? {
        guard let binding = binding(for: id) else { return nil }
        return runtime(for: id).panelURL ?? binding.panelURL(status: nil)
    }

    // MARK: - Editor

    func beginAddingService() {
        editor = ServiceEditorModel(mode: .add, binding: nil)
    }

    func beginEditingService(id: UUID) {
        guard let binding = binding(for: id) else { return }
        editor = ServiceEditorModel(mode: .edit(id), binding: binding)
    }

    func closeEditor() {
        editor = nil
    }

    // MARK: - Bindings

    @discardableResult
    func addService(
        name: String,
        startCommand: String,
        refreshSeconds: Double,
        token: String?,
        startCommandApproved: Bool,
        manifest: ServiceManifest? = nil,
        kind: ServiceKind = .manifest,
        launchdLabel: String? = nil,
        processPattern: String? = nil,
        pidFile: String? = nil,
        readOnly: Bool = false,
        statusCommand: String? = nil,
        stopCommand: String? = nil,
        panelURL: String? = nil
    ) -> ServiceBinding? {
        var binding = ServiceBinding(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            startCommand: startCommand.trimmingCharacters(in: .whitespacesAndNewlines),
            refreshSeconds: refreshSeconds,
            kind: kind,
            launchdLabel: Self.nilIfEmpty(launchdLabel),
            processPattern: Self.nilIfEmpty(processPattern),
            pidFile: Self.nilIfEmpty(pidFile),
            readOnly: readOnly,
            statusCommand: Self.nilIfEmpty(statusCommand),
            stopCommand: Self.nilIfEmpty(stopCommand),
            panelURL: Self.nilIfEmpty(panelURL),
            startCommandApproved: startCommandApproved
        )

        if let error = Self.configurationError(for: binding) {
            lastActionError = error
            return nil
        }

        if let manifest {
            binding.apply(manifest)
        }
        if binding.kind == .manifest, let token, !token.isEmpty {
            tokenStore.setToken(token, for: binding.id)
        }

        bindings.append(binding)
        var runtime = ServiceRuntime()
        if let manifest {
            runtime.manifest = manifest
            runtime.state = .running
        }
        runtimes[binding.id] = runtime
        persist()

        if manifest != nil || (binding.isProbeable && binding.kind != .manifest) {
            refresh(bindingID: binding.id)
        }
        return binding
    }

    func updateService(
        id: UUID,
        name: String,
        startCommand: String,
        refreshSeconds: Double,
        startCommandApproved: Bool,
        token: String?,
        manifest: ServiceManifest? = nil,
        kind: ServiceKind? = nil,
        launchdLabel: String? = nil,
        processPattern: String? = nil,
        pidFile: String? = nil,
        readOnly: Bool? = nil,
        statusCommand: String? = nil,
        stopCommand: String? = nil,
        panelURL: String? = nil
    ) {
        guard let index = bindings.firstIndex(where: { $0.id == id }) else { return }

        let original = bindings[index]
        let previousFingerprint = original.controlFingerprint

        bindings[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        bindings[index].startCommand = startCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        bindings[index].refreshSeconds = max(2, refreshSeconds)
        bindings[index].startCommandApproved = startCommandApproved
        if let kind {
            bindings[index].kind = kind
        }
        bindings[index].launchdLabel = Self.nilIfEmpty(launchdLabel)
        bindings[index].processPattern = Self.nilIfEmpty(processPattern)
        bindings[index].pidFile = Self.nilIfEmpty(pidFile)
        if let readOnly {
            bindings[index].readOnly = readOnly
        }
        bindings[index].statusCommand = Self.nilIfEmpty(statusCommand)
        bindings[index].stopCommand = Self.nilIfEmpty(stopCommand)
        bindings[index].panelURL = Self.nilIfEmpty(panelURL)

        if let error = Self.configurationError(for: bindings[index]) {
            lastActionError = error
            // The invalid draft is not persisted; restore the previous binding
            // so the store keeps matching services.json.
            bindings[index] = original
            return
        }

        let controlChanged = bindings[index].controlFingerprint != previousFingerprint
        if controlChanged {
            bindings[index].clearDiscovery()
            var runtime = ServiceRuntime()
            runtime.state = .offline
            runtimes[id] = runtime
            memoryHistory[id] = []
        }

        if bindings[index].kind == .manifest {
            if let token {
                tokenStore.setToken(token, for: id)
            }
        } else {
            // Tokens only apply to the manifest protocol.
            tokenStore.deleteToken(for: id)
        }
        if let manifest {
            bindings[index].apply(manifest)
            var runtime = runtime(for: id)
            runtime.manifest = manifest
            runtime.state = .running
            runtimes[id] = runtime
        }

        persist()
        lastPollAt[id] = nil
        if bindings[index].isProbeable {
            refresh(bindingID: id)
        }
    }

    func deleteService(id: UUID) {
        guard let index = bindings.firstIndex(where: { $0.id == id }) else { return }
        bindings.remove(at: index)
        tokenStore.deleteToken(for: id)
        runtimes.removeValue(forKey: id)
        memoryHistory.removeValue(forKey: id)
        lastPollAt.removeValue(forKey: id)
        pollInFlight.remove(id)
        actionInFlight.remove(id)
        pendingRefresh.remove(id)
        if editor?.editingID == id {
            editor = nil
        }
        persist()
    }

    // MARK: - Lifecycle / polling

    func startPolling() {
        guard pollTimer == nil else { return }
        isPolling = true
        pollTick()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        isPolling = false
    }

    private func pollTick() {
        let now = Date()
        for binding in bindings {
            guard binding.isProbeable else { continue }
            let interval = max(2, binding.refreshSeconds)
            if let last = lastPollAt[binding.id], now.timeIntervalSince(last) < interval {
                continue
            }
            lastPollAt[binding.id] = now
            refresh(bindingID: binding.id)
        }
    }

    // MARK: - Actions

    func start(bindingID: UUID) {
        guard let binding = binding(for: bindingID) else { return }
        guard binding.canStart else {
            lastActionError = controlError(for: binding, action: "start")
            return
        }
        guard !actionInFlight.contains(bindingID) else { return }

        actionInFlight.insert(bindingID)
        var runtime = runtime(for: bindingID)
        runtime.state = .starting
        runtime.lastError = nil
        runtime.isBusy = true
        runtimes[bindingID] = runtime

        let provider = self.provider(for: binding.kind)

        Task {
            do {
                let manifest = try await provider.start(binding)
                await MainActor.run {
                    self.actionInFlight.remove(bindingID)
                    var runtime = self.runtime(for: bindingID)
                    runtime.isBusy = false
                    if let manifest {
                        if let index = self.bindings.firstIndex(where: { $0.id == bindingID }) {
                            self.bindings[index].apply(manifest)
                            self.persist()
                        }
                        runtime.manifest = manifest
                        runtime.state = .running
                        runtime.lastError = nil
                    }
                    self.runtimes[bindingID] = runtime
                    self.lastPollAt[bindingID] = Date()
                    self.refresh(bindingID: bindingID)
                }
            } catch {
                await MainActor.run {
                    self.applyFailure(error, bindingID: bindingID, clearAction: true)
                }
            }
        }
    }

    func stop(bindingID: UUID) {
        guard let binding = binding(for: bindingID) else { return }
        guard binding.canStop else {
            lastActionError = controlError(for: binding, action: "stop")
            return
        }
        guard !actionInFlight.contains(bindingID) else { return }

        actionInFlight.insert(bindingID)
        var runtime = runtime(for: bindingID)
        runtime.isBusy = true
        runtime.lastError = nil
        runtimes[bindingID] = runtime

        let token = tokenStore.token(for: bindingID)
        let provider = self.provider(for: binding.kind)

        Task {
            do {
                try await provider.perform(.stop, for: binding, token: token)
                await MainActor.run {
                    self.actionInFlight.remove(bindingID)
                    var runtime = self.runtime(for: bindingID)
                    runtime.isBusy = false
                    runtime.state = .stopping
                    self.runtimes[bindingID] = runtime
                }

                // Give the service a moment to exit, then confirm by polling.
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    self.lastPollAt[bindingID] = Date()
                    self.refresh(bindingID: bindingID)
                }
            } catch {
                await MainActor.run {
                    self.actionInFlight.remove(bindingID)
                    self.applyActionFailure(
                        error,
                        bindingID: bindingID,
                        connectionFailureMeansStopped: binding.kind == .manifest
                    )
                }
            }
        }
    }

    func perform(_ action: ServiceControlAction, bindingID: UUID) {
        guard let binding = binding(for: bindingID) else { return }
        guard !actionInFlight.contains(bindingID) else { return }
        guard binding.kind == .manifest else {
            lastActionError = "\(binding.name) does not support \(action.rawValue)."
            return
        }

        let path: String?
        switch action {
        case .pause: path = binding.pausePath
        case .resume: path = binding.resumePath
        case .toggle: path = binding.togglePath
        case .stop: path = binding.stopPath
        }
        guard path != nil else {
            lastActionError = "\(binding.name) does not expose a \(action.rawValue) endpoint."
            return
        }

        actionInFlight.insert(bindingID)
        var runtime = runtime(for: bindingID)
        runtime.isBusy = true
        runtime.lastError = nil
        runtime.state = optimisticState(for: action, current: runtime.state)
        runtimes[bindingID] = runtime

        let token = tokenStore.token(for: bindingID)
        let provider = self.provider(for: binding.kind)

        Task {
            do {
                try await provider.perform(action, for: binding, token: token)
                await MainActor.run {
                    self.actionInFlight.remove(bindingID)
                    self.lastPollAt[bindingID] = Date()
                    self.refresh(bindingID: bindingID)
                }
            } catch {
                await MainActor.run {
                    self.actionInFlight.remove(bindingID)
                    self.applyActionFailure(
                        error,
                        bindingID: bindingID,
                        connectionFailureMeansStopped: false
                    )
                }
            }
        }
    }

    func refresh(bindingID: UUID) {
        guard let binding = binding(for: bindingID) else { return }
        guard binding.isProbeable else { return }
        guard !pollInFlight.contains(bindingID) else {
            pendingRefresh.insert(bindingID)
            return
        }

        pollInFlight.insert(bindingID)
        lastPollAt[bindingID] = Date()

        let token = tokenStore.token(for: bindingID)
        let provider = self.provider(for: binding.kind)

        Task {
            do {
                let probe = try await provider.status(for: binding, token: token)
                await MainActor.run {
                    self.applyStatus(
                        probe.status,
                        memory: probe.memory ?? probe.status.memory,
                        bindingID: bindingID
                    )
                }
            } catch {
                await MainActor.run {
                    self.applyFailure(error, bindingID: bindingID)
                }
            }
        }
    }

    // MARK: - Testing helpers (used by the service editor)

    func testStart(command: String) async throws -> ServiceManifest {
        let launcher = self.launcher
        return try await Task.detached(priority: .userInitiated) {
            try launcher.launch(bindingID: UUID(), command: command).manifest
        }.value
    }

    func testConnection(
        baseURL: URL,
        endpoints: [String: String],
        auth: ServiceManifestAuth?,
        tokenOverride: String?,
        storedTokenFor bindingID: UUID?
    ) async throws -> ServiceStatusResponse {
        let token: String?
        if let tokenOverride {
            token = tokenOverride.isEmpty ? nil : tokenOverride
        } else if let bindingID {
            token = tokenStore.token(for: bindingID)
        } else {
            token = nil
        }

        return try await client.fetchStatus(
            baseURL: baseURL,
            endpoints: endpoints,
            auth: auth,
            token: token
        )
    }

    /// Probes a draft binding from the editor without saving it.
    func testStatus(for binding: ServiceBinding) async throws -> ServiceProbeResult {
        try await provider(for: binding.kind).status(for: binding, token: nil)
    }

    /// Non-Apple launchd labels currently loaded in the user's gui domain.
    func loadedLaunchdLabels() async -> [String] {
        guard let launchd = provider(for: .launchd) as? LaunchdProvider else { return [] }
        return await launchd.loadedLabels()
    }

    // MARK: - Result application

    private func applyStatus(_ status: ServiceStatusResponse, memory: ServiceMemory?, bindingID: UUID) {
        pollInFlight.remove(bindingID)
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)

        let newState = ServiceState.from(status)
        runtime.state = newState
        runtime.pid = status.pid
        runtime.startedAt = status.startedAt
        runtime.uptimeSec = status.uptimeSec
        runtime.isBusy = false
        // A probe that reports offline is still a successful probe. Only move
        // `lastSeen` forward while the service is actually up, otherwise the
        // card would say "last seen just now" about a stopped launchd job.
        if newState == .running || newState == .paused || newState == .stopping {
            runtime.lastSeen = Date()
        }
        runtime.lastError = status.error

        if let memory {
            runtime.memory = memory
            if memory.available, let total = memory.totalRssBytes {
                memoryHistory[bindingID] = historyBuffer.append(value: Double(total), to: history(for: bindingID))
            }
        }

        if let index = bindings.firstIndex(where: { $0.id == bindingID }) {
            var changed = false
            if let service = status.service {
                if bindings[index].serviceID != service.id {
                    bindings[index].serviceID = service.id
                    changed = true
                }
                if bindings[index].serviceVersion != service.version {
                    bindings[index].serviceVersion = service.version
                    changed = true
                }
            }
            if mergeControls(status.controls, into: &bindings[index]) {
                changed = true
            }
            if changed {
                persist()
            }
        }

        if let binding = binding(for: bindingID) {
            runtime.panelURL = binding.panelURL(status: status)
        }

        runtimes[bindingID] = runtime
        flushPendingRefresh(for: bindingID)
    }

    private func applyFailure(_ error: Error, bindingID: UUID, clearAction: Bool = false) {
        pollInFlight.remove(bindingID)
        if clearAction {
            actionInFlight.remove(bindingID)
        }
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)
        runtime.isBusy = false

        if error is ServiceProviderError {
            // A failed probe means the provider could not observe the service.
            // Show offline plus the provider's explanation.
            runtime.state = .offline
            runtime.lastError = error.localizedDescription
        } else {
            let clientError = error as? ServiceClientError
            switch clientError {
            case .unauthorized:
                runtime.state = .unauthorized
                runtime.lastError = error.localizedDescription
            case .connectionFailed:
                runtime.state = .offline
                runtime.lastError = error.localizedDescription
            default:
                runtime.lastError = error.localizedDescription
                if runtime.state == .starting { runtime.state = .offline }
            }
        }

        // Deliberately keep the last memory snapshot and lastSeen timestamp.
        runtimes[bindingID] = runtime
        flushPendingRefresh(for: bindingID)
    }

    /// Runs a refresh that was requested while another probe was in flight.
    private func flushPendingRefresh(for bindingID: UUID) {
        guard pendingRefresh.remove(bindingID) != nil else { return }
        refresh(bindingID: bindingID)
    }

    private func applyActionFailure(
        _ error: Error,
        bindingID: UUID,
        connectionFailureMeansStopped: Bool
    ) {
        actionInFlight.remove(bindingID)
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)
        runtime.isBusy = false

        guard !(error is ServiceProviderError) else {
            runtime.lastError = error.localizedDescription
            runtimes[bindingID] = runtime
            return
        }

        let clientError = error as? ServiceClientError
        switch clientError {
        case .unauthorized:
            runtime.state = .unauthorized
            runtime.lastError = error.localizedDescription
        case .connectionFailed:
            // A connection failure during stop means the service is already
            // gone; elsewhere it just means the service is unreachable.
            runtime.state = .offline
            runtime.lastError = connectionFailureMeansStopped ? nil : error.localizedDescription
        default:
            runtime.lastError = error.localizedDescription
        }

        runtimes[bindingID] = runtime
    }

    private func optimisticState(for action: ServiceControlAction, current: ServiceState) -> ServiceState {
        switch action {
        case .pause: return .paused
        case .resume: return .running
        case .toggle:
            if current == .paused { return .running }
            if current == .running { return .paused }
            return current
        case .stop: return .stopping
        }
    }

    /// The status payload also describes endpoints. Fill in anything the
    /// manifest omitted so older services still get working controls.
    private func mergeControls(_ controls: ServiceControls?, into binding: inout ServiceBinding) -> Bool {
        guard let controls else { return false }
        var endpoints = binding.endpoints ?? [:]
        let candidates: [(String, ServiceControlEndpoint?)] = [
            ("status", controls.status),
            ("memory", controls.memory),
            ("pause", controls.pause),
            ("resume", controls.resume),
            ("toggle", controls.toggle),
            ("stop", controls.stop)
        ]

        var changed = false
        for (key, endpoint) in candidates {
            guard endpoints[key] == nil, let path = endpoint?.path, !path.isEmpty else { continue }
            endpoints[key] = path
            changed = true
        }

        if changed {
            binding.endpoints = endpoints
        }
        return changed
    }

    // MARK: - Validation

    private func controlError(for binding: ServiceBinding, action: String) -> String {
        if binding.readOnly {
            return "\(binding.name) is read-only. Edit the service to allow control."
        }
        if !binding.startCommandApproved {
            return "Controlling \(binding.name) has not been approved. Edit the service to allow it."
        }
        switch binding.kind {
        case .manifest:
            return action == "start"
                ? "\(binding.name) needs a start command."
                : "\(binding.name) does not expose a stop endpoint."
        case .launchd:
            return "\(binding.name) needs a launchd label."
        case .process:
            return action == "start"
                ? "\(binding.name) has no start command. Add one or turn on Read-only."
                : "\(binding.name) has no stop command. Add one or turn on Read-only."
        case .command:
            return action == "start"
                ? "\(binding.name) has no start command. Add one or turn on Read-only."
                : "\(binding.name) has no stop command. Add one or turn on Read-only."
        }
    }

    private static func configurationError(for binding: ServiceBinding) -> String? {
        if binding.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "A service needs a name."
        }

        switch binding.kind {
        case .manifest:
            if binding.trimmedStartCommand.isEmpty {
                return "A manifest service needs a start command."
            }
        case .launchd:
            if binding.trimmedLaunchdLabel == nil {
                return "A launchd service needs a label."
            }
        case .process:
            if binding.trimmedProcessPattern == nil && binding.trimmedPIDFile == nil {
                return "A process service needs a pgrep pattern or a PID file."
            }
        case .command:
            if binding.trimmedStatusCommand == nil {
                return "A command service needs a status command."
            }
        }
        return nil
    }

    private static func nilIfEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist() {
        do {
            try bindingStore.save(bindings)
        } catch {
            lastActionError = "Could not save services: \(error.localizedDescription)"
        }
    }
}
