import SwiftUI
import AppKit
import Darwin
import UniformTypeIdentifiers

/// Add / Edit Service, shown as a page inside the Services pane.
///
/// It is deliberately not a sheet: sheets attached to a transient popover get
/// orphaned when the popover closes, which left the pane modal and dead. As a
/// page with a store-owned draft, the form also survives closing and reopening
/// the popover.
struct ServiceEditorView: View {
    @ObservedObject var model: ServiceEditorModel
    @ObservedObject var servicesStore: ServicesStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    typePicker
                    nameField
                    kindFields
                    panelURLField
                    refreshField
                    approvalToggle
                    manifestSection
                    warnings
                    testResultBox
                }
                .padding(Design.Spacing.page)
            }
            Divider()
            toolbar
        }
        .onChange(of: model.controlFingerprint) { _, newValue in
            guard let existing = existingBinding, newValue != existing.controlFingerprint else { return }
            // A changed control target must be re-approved before iGlance will
            // run commands or act on the service.
            model.approved = false
            model.parsedManifest = nil
        }
        .onChange(of: model.kind) { _, newValue in
            model.readOnly = (newValue == .launchd)
            model.testResult = nil
            model.parsedManifest = nil
            // A new provider binding must be approved explicitly before it can
            // run anything. Manifest bindings keep their historical default.
            if newValue != .manifest && model.editingID == nil {
                model.approved = false
            }
        }
        .onChange(of: model.readOnly) { oldValue, newValue in
            // Turning observation-only off enables Start/Stop, so require an
            // explicit approval instead of inheriting the pre-read-only state.
            if oldValue && !newValue {
                model.approved = false
            }
        }
        .onChange(of: model.token) { _, newValue in
            if !newValue.isEmpty {
                model.removesStoredToken = false
            }
        }
        .task(id: model.kind) {
            if model.kind == .launchd {
                await loadLaunchdLabels()
            }
        }
    }

    private var existingBinding: ServiceBinding? {
        guard let id = model.editingID else { return nil }
        return servicesStore.binding(for: id)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.isEditing ? "Edit Service" : "Add Service")
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                servicesStore.closeEditor()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Design.Spacing.page)
        .padding(.vertical, 12)
    }

    private var headerSubtitle: String {
        model.kind == .manifest
            ? "Tokens are stored in the macOS Keychain"
            : "iGlance observes and optionally controls this service"
    }

    // MARK: - Type

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Type")
            Picker("Type", selection: $model.kind) {
                ForEach(ServiceKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(model.kind.explanation)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var kindFields: some View {
        switch model.kind {
        case .manifest:
            commandField
            tokenField
        case .launchd:
            launchdFields
            readOnlyToggle
        case .process:
            processFields
            startStopCommands
            readOnlyToggle
        case .command:
            commandFields
            startStopCommands
            readOnlyToggle
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel("Name")
            TextField("Gofer", text: $model.name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var commandField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                fieldLabel("Start command")
                Spacer()
                Button("Choose Script…") {
                    chooseStartScript()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.tint)
            }

            TextField("Command to run", text: $model.startCommand, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(2...4)
                .padding(8)
                .background(fieldBackground)
                .overlay(fieldBorder)

            Text("Runs with /bin/zsh -lc. The command must be idempotent and print an IGLANCE_SERVICE_MANIFEST line when the service is ready.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tokenField: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel("API token (optional)")
            SecureField(storedToken ? "Stored in Keychain — leave blank to keep" : "Token value", text: $model.token)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text(tokenHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if storedToken {
                    Spacer()

                    if model.removesStoredToken {
                        Button("Undo removal") {
                            model.removesStoredToken = false
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    } else if model.token.isEmpty {
                        Button("Remove stored token") {
                            model.removesStoredToken = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    } else {
                        Button("Keep stored token") {
                            model.token = ""
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    // MARK: - launchd

    private var launchdFields: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                fieldLabel("Launchd label")
                Spacer()
                Menu {
                    if model.isLoadingLabels {
                        Text("Loading…")
                    } else if model.loadedLaunchdLabels.isEmpty {
                        Text("No non-Apple jobs loaded")
                    } else {
                        ForEach(model.loadedLaunchdLabels, id: \.self) { label in
                            Button(label) {
                                model.launchdLabel = label
                            }
                        }
                    }
                } label: {
                    Text("Choose Loaded Job…")
                        .font(.caption2)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Choose from launchctl list")
            }

            TextField("ai.hermes.gateway", text: $model.launchdLabel)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(fieldBackground)
                .overlay(fieldBorder)

            Text("Observed in gui/\(getuid()) and the system domain (LaunchDaemons). Read-only is recommended so iGlance never competes with launchd.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - process / command

    private var processFields: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("Match by process")
            TextField("pgrep -f pattern, e.g. hermes gateway", text: $model.processPattern)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(fieldBackground)
                .overlay(fieldBorder)

            fieldLabel("…or PID file")
            TextField("/tmp/hermes.pid", text: $model.pidFile)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(fieldBackground)
                .overlay(fieldBorder)

            Text("The pattern is passed to pgrep as a literal argument. Child processes are included in the memory total. If both are set, the PID file wins when it contains a live PID.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var commandFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            commandTextField(
                "Status command",
                placeholder: "hermes gateway status",
                text: $model.statusCommand,
                hint: "Exit 0 means running. It may also print a JSON status object with state, pid, uptime_sec, and memory."
            )
        }
    }

    private var startStopCommands: some View {
        VStack(alignment: .leading, spacing: 8) {
            commandTextField(
                "Start command (optional)",
                placeholder: "hermes gateway start",
                text: $model.startCommand,
                hint: "Runs only after you approve control. Leave empty for observation-only."
            )
            commandTextField(
                "Stop command (optional)",
                placeholder: "hermes gateway stop",
                text: $model.stopCommand,
                hint: nil
            )
        }
    }

    private func commandTextField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        hint: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(title)
            TextField(placeholder, text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1...3)
                .padding(8)
                .background(fieldBackground)
                .overlay(fieldBorder)

            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var readOnlyToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Read-only (observe only)", isOn: $model.readOnly)
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)

            Text(readOnlyHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var readOnlyHint: String {
        switch model.kind {
        case .manifest:
            return ""
        case .launchd:
            return "Recommended for launchd. iGlance is not the supervisor; Stop unloads the job with launchctl bootout."
        case .process, .command:
            return "No start or stop command is ever run while this is on."
        }
    }

    private var panelURLField: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel("Panel URL (optional)")
            TextField("https://hermes.gateway/router", text: $model.panelURL)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(fieldBackground)
                .overlay(fieldBorder)

            Text(panelURLHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var panelURLHint: String {
        switch model.kind {
        case .manifest:
            return "Requested if the service does not report its own panel (urls.panel or endpoints.panel). http(s) only."
        case .launchd, .process, .command:
            return "Adds an Open Panel button to the card while the service is running or paused. http(s) only."
        }
    }

    // MARK: - Common fields

    private var refreshField: some View {
        HStack(spacing: 8) {
            Text("Refresh every \(Int(model.refreshSeconds), format: .number)s")
                .font(.caption)
            Spacer()
            Stepper("Refresh interval", value: $model.refreshSeconds, in: 2...60, step: 1)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var approvalToggle: some View {
        if !model.readOnly {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(approvalTitle, isOn: $model.approved)
                    .font(.caption)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                if !model.approved {
                    Text("Start, Stop, and Test stay disabled until this is on.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var approvalTitle: String {
        switch model.kind {
        case .manifest:
            return "Allow iGlance to run this command and control the service"
        case .launchd:
            return "Allow iGlance to start and stop this launchd job"
        case .process:
            return "Allow iGlance to run the start/stop commands and control the processes"
        case .command:
            return "Allow iGlance to run the start/stop commands and control the service"
        }
    }

    private var manifestSection: some View {
        Group {
            if model.kind == .manifest {
                DisclosureGroup(isExpanded: $model.showsManifest) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Paste an IGLANCE_SERVICE_MANIFEST line (or just its JSON) when the start command can't print one.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("IGLANCE_SERVICE_MANIFEST {…}", text: $model.manifestLine, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(3...5)
                            .padding(8)
                            .background(fieldBackground)
                            .overlay(fieldBorder)

                        HStack(spacing: 8) {
                            Button("Use Manifest", action: applyManifestLine)
                                .controlSize(.small)
                            if let parsedManifest = model.parsedManifest {
                                Text("\(parsedManifest.service.id) · \(parsedManifest.baseURL.absoluteString)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if let existing = existingBinding, model.parsedManifest == nil, let baseURL = existing.baseURL {
                            Text("Cached: \(baseURL.absoluteString) · \(existing.endpoints?.count ?? 0) endpoints")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Manifest (optional)")
                        .font(.caption.weight(.medium))
                }
            }
        }
    }

    @ViewBuilder
    private var warnings: some View {
        if model.kind == .manifest,
           let baseURL = effectiveBaseURL,
           !ServiceManifestParser.isLoopback(baseURL) {
            warning("This is not a loopback address (\(baseURL.absoluteString)). Plain HTTP to another host is not recommended.")
        }

        if let existing = existingBinding, !existing.startCommandApproved, model.approved {
            warning("Only enable this if you trust the command and the service.")
        }

        if model.kind == .launchd, !model.readOnly {
            warning("Stopping a launchd job unloads it. launchd will load it again at the next login.")
        }
    }

    @ViewBuilder
    private var testResultBox: some View {
        if let testResult = model.testResult {
            switch testResult {
            case .success(let message):
                resultRow(message, icon: "checkmark.circle.fill", tint: .green)
            case .failure(let message):
                resultRow(message, icon: "exclamationmark.triangle.fill", tint: .orange)
            }
        }
    }

    private func resultRow(_ message: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: Design.Radius.chip, style: .continuous))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            if model.isTesting {
                ProgressView()
                    .controlSize(.mini)
            }

            if model.kind == .manifest {
                Button("Test Start") {
                    runTestStart()
                }
                .disabled(model.isTesting || model.trimmedCommand.isEmpty || !model.approved)
                .help("Run the start command and read the manifest")

                Button("Test Connection") {
                    runTestConnection()
                }
                .disabled(model.isTesting || effectiveBaseURL == nil)
            } else {
                Button("Test Status") {
                    runTestStatus()
                }
                .disabled(model.isTesting || !model.isProbeable)
                .help("Probe the service without saving")
            }

            Spacer()

            Button("Cancel") {
                servicesStore.closeEditor()
            }

            Button("Save") {
                save()
            }
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.small)
        .padding(.horizontal, Design.Spacing.page)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func chooseStartScript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.shellScript, .executable, .plainText]
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let quoted = "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        if model.trimmedCommand.isEmpty {
            model.startCommand = quoted
        } else {
            model.startCommand += " " + quoted
        }
    }

    private func save() {
        if let error = configurationError() {
            model.testResult = .failure(error)
            return
        }

        let manifest: ServiceManifest?
        if model.kind == .manifest {
            do {
                manifest = try manifestForSaving()
            } catch {
                model.testResult = .failure(error.localizedDescription)
                return
            }
        } else {
            manifest = nil
        }

        servicesStore.lastActionError = nil

        if let id = model.editingID {
            servicesStore.updateService(
                id: id,
                name: model.trimmedName,
                startCommand: model.trimmedCommand,
                refreshSeconds: model.refreshSeconds,
                startCommandApproved: model.approved,
                token: tokenOverride,
                manifest: manifest,
                kind: model.kind,
                launchdLabel: model.trimmedLaunchdLabel,
                processPattern: model.trimmedProcessPattern,
                pidFile: model.trimmedPIDFile,
                readOnly: model.readOnly,
                statusCommand: model.trimmedStatusCommand,
                stopCommand: model.trimmedStopCommand,
                panelURL: model.trimmedPanelURL
            )
            if let error = servicesStore.lastActionError {
                model.testResult = .failure(error)
                return
            }
        } else {
            let binding = servicesStore.addService(
                name: model.trimmedName,
                startCommand: model.trimmedCommand,
                refreshSeconds: model.refreshSeconds,
                token: tokenOverride,
                startCommandApproved: model.approved,
                manifest: manifest,
                kind: model.kind,
                launchdLabel: model.trimmedLaunchdLabel,
                processPattern: model.trimmedProcessPattern,
                pidFile: model.trimmedPIDFile,
                readOnly: model.readOnly,
                statusCommand: model.trimmedStatusCommand,
                stopCommand: model.trimmedStopCommand,
                panelURL: model.trimmedPanelURL
            )
            guard binding != nil else {
                model.testResult = .failure(servicesStore.lastActionError ?? "The service could not be saved.")
                return
            }
        }

        servicesStore.closeEditor()
    }

    private func configurationError() -> String? {
        guard !model.trimmedName.isEmpty else {
            return "A name is required."
        }

        switch model.kind {
        case .manifest:
            guard !model.trimmedCommand.isEmpty else {
                return "A start command is required."
            }
        case .launchd:
            guard !model.trimmedLaunchdLabel.isEmpty else {
                return "A launchd label is required."
            }
        case .process:
            guard !model.trimmedProcessPattern.isEmpty || !model.trimmedPIDFile.isEmpty else {
                return "A pgrep pattern or a PID file is required."
            }
        case .command:
            guard !model.trimmedStatusCommand.isEmpty else {
                return "A status command is required."
            }
        }
        return nil
    }

    private func manifestForSaving() throws -> ServiceManifest? {
        if !model.manifestLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try parseManifestInput()
        }
        return model.parsedManifest
    }

    // MARK: - Tests

    private func runTestStart() {
        model.testResult = nil
        model.isTesting = true

        Task {
            do {
                let manifest = try await servicesStore.testStart(command: model.startCommand)
                await MainActor.run {
                    model.parsedManifest = manifest
                    let version = manifest.service.version.map { " \($0)" } ?? ""
                    model.testResult = .success(
                        "Manifest received from \(manifest.service.name)\(version): "
                        + "\(manifest.baseURL.absoluteString), \(manifest.endpoints.count) endpoints."
                    )
                    model.isTesting = false
                }
            } catch {
                await MainActor.run {
                    model.testResult = .failure(error.localizedDescription)
                    model.isTesting = false
                }
            }
        }
    }

    private func runTestStatus() {
        model.testResult = nil

        guard model.isProbeable else {
            model.testResult = .failure("The service needs a label, a process match, or a status command.")
            return
        }

        model.isTesting = true
        let draft = model.draftBinding()

        Task {
            do {
                let probe = try await servicesStore.testStatus(for: draft)
                await MainActor.run {
                    let state = ServiceState.from(probe.status)
                    let memory = probe.memory.map { memory -> String in
                        memory.available ? Formatters.formatByteCount(memory.totalRssBytes) : "—"
                    } ?? "—"
                    let detail = probe.status.error.map { " — \($0)" } ?? ""
                    let message = "\(state.label)"
                        + (probe.status.pid.map { ", pid \($0)" } ?? "")
                        + ", memory \(memory)"
                        + detail
                    model.testResult = probe.status.error == nil ? .success(message) : .failure(message)
                    model.isTesting = false
                }
            } catch {
                await MainActor.run {
                    model.testResult = .failure(error.localizedDescription)
                    model.isTesting = false
                }
            }
        }
    }

    private func runTestConnection() {
        model.testResult = nil

        guard let baseURL = effectiveBaseURL else {
            model.testResult = .failure("No base URL yet — run Test Start or paste a manifest first.")
            return
        }

        let manifest = model.parsedManifest ?? (try? parseManifestInput())
        let endpoints = manifest?.endpoints ?? existingBinding?.endpoints ?? [:]
        let auth = manifest?.auth ?? existingBinding?.auth

        guard endpoints["status"] != nil else {
            model.testResult = .failure("No status endpoint is known yet. Run Test Start or paste a manifest.")
            return
        }

        model.isTesting = true
        Task {
            do {
                let status = try await servicesStore.testConnection(
                    baseURL: baseURL,
                    endpoints: endpoints,
                    auth: auth,
                    tokenOverride: tokenOverride,
                    storedTokenFor: model.editingID
                )
                await MainActor.run {
                    let state = ServiceState.from(status)
                    let memory = status.memory.map { memory -> String in
                        memory.available ? Formatters.formatByteCount(memory.totalRssBytes) : "—"
                    } ?? "—"
                    model.testResult = .success(
                        "Connected: \(state.label)"
                        + (status.pid.map { ", pid \($0)" } ?? "")
                        + ", memory \(memory)."
                    )
                    model.isTesting = false
                }
            } catch {
                await MainActor.run {
                    model.testResult = .failure(error.localizedDescription)
                    model.isTesting = false
                }
            }
        }
    }

    private func applyManifestLine() {
        do {
            guard let manifest = try parseManifestInput() else {
                model.testResult = .failure("Paste a manifest line first.")
                return
            }
            model.parsedManifest = manifest
            model.testResult = .success(
                "Manifest loaded: \(manifest.service.name) \(manifest.service.version ?? ""), "
                + "\(manifest.baseURL.absoluteString)."
            )
        } catch {
            model.testResult = .failure(error.localizedDescription)
        }
    }

    private func parseManifestInput() throws -> ServiceManifest? {
        let value = model.manifestLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("{") {
            return try ServiceManifestParser.parse(line: "\(ServiceManifestParser.prefix) \(value)")
        }
        return try ServiceManifestParser.parse(line: value)
    }

    private func loadLaunchdLabels() async {
        guard !model.isLoadingLabels else { return }
        await MainActor.run { model.isLoadingLabels = true }
        let labels = await servicesStore.loadedLaunchdLabels()
        await MainActor.run {
            model.loadedLaunchdLabels = labels
            model.isLoadingLabels = false
        }
    }

    // MARK: - Helpers

    private var storedToken: Bool {
        guard let id = model.editingID else { return false }
        return servicesStore.hasToken(for: id)
    }

    /// `nil` keeps the stored token, `""` removes it, any other value replaces it.
    private var tokenOverride: String? {
        guard model.editingID != nil else {
            return model.token.isEmpty ? nil : model.token
        }
        if !model.token.isEmpty {
            return model.token
        }
        return model.removesStoredToken ? "" : nil
    }

    private var tokenHint: String {
        if storedToken {
            if model.removesStoredToken {
                return "The stored token will be removed on save."
            }
            if !model.token.isEmpty {
                return "The new token will replace the stored one."
            }
            return "A token is stored in the Keychain."
        }

        return model.token.isEmpty
            ? "Leave empty if the service doesn't need a token."
            : "The token will be stored in the Keychain."
    }

    private var effectiveBaseURL: URL? {
        if let parsedManifest = model.parsedManifest {
            return parsedManifest.baseURL
        }
        if let pasted = try? parseManifestInput() {
            return pasted.baseURL
        }
        return existingBinding?.baseURL
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: Design.Radius.field, style: .continuous)
            .fill(Color.primary.opacity(0.04))
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: Design.Radius.field, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.7)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func warning(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
