import SwiftUI
import AppKit
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
                    nameField
                    commandField
                    tokenField
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
        .onChange(of: model.startCommand) { _, newValue in
            guard let existing = existingBinding, newValue != existing.startCommand else { return }
            // A changed command must be re-approved before iGlance will run it.
            model.approved = false
            model.parsedManifest = nil
        }
        .onChange(of: model.token) { _, newValue in
            if !newValue.isEmpty {
                model.removesStoredToken = false
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
                Text("Tokens are stored in the macOS Keychain")
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

    // MARK: - Fields

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

    private var refreshField: some View {
        HStack(spacing: 8) {
            Text("Refresh every \(Int(model.refreshSeconds), format: .number)s")
                .font(.caption)
            Spacer()
            Stepper("Refresh interval", value: $model.refreshSeconds, in: 2...60, step: 1)
                .labelsHidden()
        }
    }

    private var approvalToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Allow iGlance to run this command and control the service", isOn: $model.approved)
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)

            if !model.approved {
                Text("Start, Pause, Resume, Stop, and Test Start stay disabled until this is on.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var manifestSection: some View {
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

    @ViewBuilder
    private var warnings: some View {
        if let baseURL = effectiveBaseURL, !ServiceManifestParser.isLoopback(baseURL) {
            warning("This is not a loopback address (\(baseURL.absoluteString)). Plain HTTP to another host is not recommended.")
        }

        if let existing = existingBinding, !existing.startCommandApproved, model.approved {
            warning("Only enable this if you trust the command above.")
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

            Button("Test Start") {
                runTestStart()
            }
            .disabled(model.isTesting || model.trimmedCommand.isEmpty || !model.approved)
            .help("Run the start command and read the manifest")

            Button("Test Connection") {
                runTestConnection()
            }
            .disabled(model.isTesting || effectiveBaseURL == nil)

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
        guard !model.trimmedName.isEmpty else {
            model.testResult = .failure("A name is required.")
            return
        }
        guard !model.trimmedCommand.isEmpty else {
            model.testResult = .failure("A start command is required.")
            return
        }

        let manifest: ServiceManifest?
        do {
            manifest = try manifestForSaving()
        } catch {
            model.testResult = .failure(error.localizedDescription)
            return
        }

        if let id = model.editingID {
            servicesStore.updateService(
                id: id,
                name: model.trimmedName,
                startCommand: model.trimmedCommand,
                refreshSeconds: model.refreshSeconds,
                startCommandApproved: model.approved,
                token: tokenOverride,
                manifest: manifest
            )
        } else {
            let binding = servicesStore.addService(
                name: model.trimmedName,
                startCommand: model.trimmedCommand,
                refreshSeconds: model.refreshSeconds,
                token: tokenOverride,
                startCommandApproved: model.approved,
                manifest: manifest
            )
            guard binding != nil else {
                model.testResult = .failure(servicesStore.lastActionError ?? "The service could not be saved.")
                return
            }
        }

        servicesStore.closeEditor()
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
