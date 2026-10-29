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

    private var pollTimer: Timer?
    private var lastPollAt: [UUID: Date] = [:]
    private var inFlight: Set<UUID> = []
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
        manifest: ServiceManifest? = nil
    ) -> ServiceBinding? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = startCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !command.isEmpty else {
            lastActionError = "A service needs a name and a start command."
            return nil
        }

        var binding = ServiceBinding(
            name: name,
            startCommand: command,
            refreshSeconds: refreshSeconds,
            startCommandApproved: startCommandApproved
        )
        if let manifest {
            binding.apply(manifest)
        }
        if let token, !token.isEmpty {
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

        if manifest != nil {
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
        manifest: ServiceManifest? = nil
    ) {
        guard let index = bindings.firstIndex(where: { $0.id == id }) else { return }

        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = startCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !command.isEmpty else {
            lastActionError = "A service needs a name and a start command."
            return
        }

        let commandChanged = command != bindings[index].startCommand
        bindings[index].name = name
        bindings[index].startCommand = command
        bindings[index].refreshSeconds = max(2, refreshSeconds)
        bindings[index].startCommandApproved = startCommandApproved

        if commandChanged {
            bindings[index].clearDiscovery()
            var runtime = ServiceRuntime()
            runtime.state = .offline
            runtimes[id] = runtime
            memoryHistory[id] = []
        }

        if let token {
            tokenStore.setToken(token, for: id)
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
        if bindings[index].baseURL != nil {
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
        inFlight.remove(id)
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
            guard binding.baseURL != nil else { continue }
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
        guard binding.startCommandApproved else {
            lastActionError = "This start command has not been approved. Edit the service to allow it."
            return
        }
        guard !inFlight.contains(bindingID) else { return }

        inFlight.insert(bindingID)
        var runtime = runtime(for: bindingID)
        runtime.state = .starting
        runtime.lastError = nil
        runtime.isBusy = true
        runtimes[bindingID] = runtime

        let command = binding.startCommand
        let launcher = self.launcher

        Task {
            let result: Result<ServiceLaunchOutcome, Error> = await Task.detached(priority: .userInitiated) {
                Result { try launcher.launch(bindingID: bindingID, command: command) }
            }.value

            await MainActor.run {
                self.inFlight.remove(bindingID)
                self.applyLaunchResult(result, bindingID: bindingID)
            }
        }
    }

    func stop(bindingID: UUID) {
        guard let binding = binding(for: bindingID) else { return }
        guard binding.stopPath != nil else {
            lastActionError = "\(binding.name) does not expose a stop endpoint."
            return
        }
        guard !inFlight.contains(bindingID) else { return }

        inFlight.insert(bindingID)
        var runtime = runtime(for: bindingID)
        runtime.isBusy = true
        runtime.lastError = nil
        runtimes[bindingID] = runtime

        let token = tokenStore.token(for: bindingID)
        let client = self.client

        Task {
            do {
                try await client.perform(.stop, binding: binding, token: token)
                await MainActor.run {
                    self.inFlight.remove(bindingID)
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
                    self.inFlight.remove(bindingID)
                    self.applyActionFailure(
                        error,
                        bindingID: bindingID,
                        connectionFailureMeansStopped: true
                    )
                }
            }
        }
    }

    func perform(_ action: ServiceControlAction, bindingID: UUID) {
        guard let binding = binding(for: bindingID) else { return }
        guard !inFlight.contains(bindingID) else { return }

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

        inFlight.insert(bindingID)
        var runtime = runtime(for: bindingID)
        runtime.isBusy = true
        runtime.lastError = nil
        runtime.state = optimisticState(for: action, current: runtime.state)
        runtimes[bindingID] = runtime

        let token = tokenStore.token(for: bindingID)
        let client = self.client

        Task {
            do {
                try await client.perform(action, binding: binding, token: token)
                await MainActor.run {
                    self.inFlight.remove(bindingID)
                    self.lastPollAt[bindingID] = Date()
                    self.refresh(bindingID: bindingID)
                }
            } catch {
                await MainActor.run {
                    self.inFlight.remove(bindingID)
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
        guard binding.baseURL != nil else { return }
        guard !inFlight.contains(bindingID) else { return }

        inFlight.insert(bindingID)
        lastPollAt[bindingID] = Date()

        let token = tokenStore.token(for: bindingID)
        let client = self.client

        Task {
            do {
                let status = try await client.fetchStatus(binding: binding, token: token)
                var fetchedMemory = status.memory
                if fetchedMemory == nil, binding.memoryPath != nil {
                    fetchedMemory = try? await client.fetchMemory(binding: binding, token: token)
                }
                let memory = fetchedMemory
                await MainActor.run {
                    self.applyStatus(status, memory: memory, bindingID: bindingID)
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

    // MARK: - Result application

    private func applyLaunchResult(_ result: Result<ServiceLaunchOutcome, Error>, bindingID: UUID) {
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)
        runtime.isBusy = false

        switch result {
        case .success(let outcome):
            if let index = bindings.firstIndex(where: { $0.id == bindingID }) {
                bindings[index].apply(outcome.manifest)
                persist()
            }
            runtime.manifest = outcome.manifest
            runtime.state = .running
            runtime.lastError = nil
            runtimes[bindingID] = runtime
            refresh(bindingID: bindingID)

        case .failure(let error):
            runtime.state = .offline
            runtime.lastError = error.localizedDescription
            runtimes[bindingID] = runtime
        }
    }

    private func applyStatus(_ status: ServiceStatusResponse, memory: ServiceMemory?, bindingID: UUID) {
        inFlight.remove(bindingID)
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)

        runtime.state = ServiceState.from(status)
        runtime.pid = status.pid
        runtime.startedAt = status.startedAt
        runtime.uptimeSec = status.uptimeSec
        runtime.isBusy = false
        runtime.lastSeen = Date()
        runtime.lastError = nil

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
    }

    private func applyFailure(_ error: Error, bindingID: UUID) {
        inFlight.remove(bindingID)
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)
        runtime.isBusy = false

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

        // Deliberately keep the last memory snapshot and lastSeen timestamp.
        runtimes[bindingID] = runtime
    }

    private func applyActionFailure(
        _ error: Error,
        bindingID: UUID,
        connectionFailureMeansStopped: Bool
    ) {
        inFlight.remove(bindingID)
        guard bindings.contains(where: { $0.id == bindingID }) else { return }
        var runtime = runtime(for: bindingID)
        runtime.isBusy = false

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

    private func persist() {
        do {
            try bindingStore.save(bindings)
        } catch {
            lastActionError = "Could not save services: \(error.localizedDescription)"
        }
    }
}
