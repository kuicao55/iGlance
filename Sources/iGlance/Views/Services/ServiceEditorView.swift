import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ServiceEditorView: View {
    @ObservedObject var servicesStore: ServicesStore
    let existing: ServiceBinding?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startCommand = ""
    @State private var token = ""
    @State private var removesStoredToken = false
    @State private var refreshSeconds: Double = 5
    @State private var approved = true
    @State private var manifestLine = ""
    @State private var parsedManifest: ServiceManifest?
    @State private var didLoad = false
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var showsManifest = false

    private enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

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
                .padding(16)
            }
            Divider()
            toolbar
        }
        .frame(width: 430, height: 540)
        .onAppear(perform: loadIfNeeded)
        .onChange(of: startCommand) { _, newValue in
            guard let existing, newValue != existing.startCommand else { return }
            // A changed command must be re-approved before iGlance will run it.
            approved = false
            parsedManifest = nil
        }
        .onChange(of: token) { _, newValue in
            if !newValue.isEmpty {
                removesStoredToken = false
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(existing == nil ? "Add Service" : "Edit Service")
                    .font(.headline)
                Text("Tokens are stored in the macOS Keychain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel("Name")
            TextField("Gofer", text: $name)
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

            TextField("Command to run", text: $startCommand, axis: .vertical)
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
            SecureField(storedToken ? "Stored in Keychain — leave blank to keep" : "Token value", text: $token)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text(tokenHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if storedToken {
                    Spacer()

                    if removesStoredToken {
                        Button("Undo removal") {
                            removesStoredToken = false
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.tint)
                    } else if token.isEmpty {
                        Button("Remove stored token") {
                            removesStoredToken = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    } else {
                        Button("Keep stored token") {
                            token = ""
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
            Text("Refresh every \(Int(refreshSeconds), format: .number)s")
                .font(.caption)
            Spacer()
            Stepper("Refresh interval", value: $refreshSeconds, in: 2...60, step: 1)
                .labelsHidden()
        }
    }

    private var approvalToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Allow iGlance to run this command and control the service", isOn: $approved)
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)

            if !approved {
                Text("Start, Pause, Resume, Stop, and Test Start stay disabled until this is on.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var manifestSection: some View {
        DisclosureGroup(isExpanded: $showsManifest) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Paste an IGLANCE_SERVICE_MANIFEST line (or just its JSON) when the start command can't print one.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("IGLANCE_SERVICE_MANIFEST {…}", text: $manifestLine, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(3...5)
                    .padding(8)
                    .background(fieldBackground)
                    .overlay(fieldBorder)

                HStack(spacing: 8) {
                    Button("Use Manifest", action: applyManifestLine)
                        .controlSize(.small)
                    if let parsedManifest {
                        Text("\(parsedManifest.service.id) · \(parsedManifest.baseURL.absoluteString)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let existing, parsedManifest == nil, let baseURL = existing.baseURL {
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

        if existing != nil, existing?.startCommandApproved != true, approved {
            warning("Only enable this if you trust the command above.")
        }
    }

    @ViewBuilder
    private var testResultBox: some View {
        if let testResult {
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
            if isTesting {
                ProgressView()
                    .controlSize(.mini)
            }

            Button("Test Start") {
                runTestStart()
            }
            .disabled(isTesting || startCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !approved)
            .help("Run the start command and read the manifest")

            Button("Test Connection") {
                runTestConnection()
            }
            .disabled(isTesting || effectiveBaseURL == nil)

            Spacer()

            Button("Cancel") {
                dismiss()
            }

            Button("Save") {
                save()
            }
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Load / save

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing else { return }

        name = existing.name
        startCommand = existing.startCommand
        refreshSeconds = existing.refreshSeconds
        approved = existing.startCommandApproved
    }

    private func chooseStartScript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.shellScript, .executable, .plainText]
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let quoted = "'" + url.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        if startCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startCommand = quoted
        } else {
            startCommand += " " + quoted
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = startCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            testResult = .failure("A name is required.")
            return
        }
        guard !trimmedCommand.isEmpty else {
            testResult = .failure("A start command is required.")
            return
        }

        let manifest: ServiceManifest?
        do {
            manifest = try manifestForSaving()
        } catch {
            testResult = .failure(error.localizedDescription)
            return
        }

        if let existing {
            servicesStore.updateService(
                id: existing.id,
                name: trimmedName,
                startCommand: trimmedCommand,
                refreshSeconds: refreshSeconds,
                startCommandApproved: approved,
                token: tokenOverride,
                manifest: manifest
            )
        } else {
            let binding = servicesStore.addService(
                name: trimmedName,
                startCommand: trimmedCommand,
                refreshSeconds: refreshSeconds,
                token: tokenOverride,
                startCommandApproved: approved,
                manifest: manifest
            )
            guard binding != nil else {
                testResult = .failure(servicesStore.lastActionError ?? "The service could not be saved.")
                return
            }
        }

        dismiss()
    }

    private func manifestForSaving() throws -> ServiceManifest? {
        if !manifestLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try parseManifestInput()
        }
        return parsedManifest
    }

    // MARK: - Tests

    private func runTestStart() {
        testResult = nil
        isTesting = true

        Task {
            do {
                let manifest = try await servicesStore.testStart(command: startCommand)
                await MainActor.run {
                    parsedManifest = manifest
                    let version = manifest.service.version.map { " \($0)" } ?? ""
                    testResult = .success(
                        "Manifest received from \(manifest.service.name)\(version): "
                        + "\(manifest.baseURL.absoluteString), \(manifest.endpoints.count) endpoints."
                    )
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func runTestConnection() {
        testResult = nil

        guard let baseURL = effectiveBaseURL else {
            testResult = .failure("No base URL yet — run Test Start or paste a manifest first.")
            return
        }

        let manifest = parsedManifest ?? (try? parseManifestInput())
        let endpoints = manifest?.endpoints ?? existing?.endpoints ?? [:]
        let auth = manifest?.auth ?? existing?.auth

        guard endpoints["status"] != nil else {
            testResult = .failure("No status endpoint is known yet. Run Test Start or paste a manifest.")
            return
        }

        isTesting = true
        Task {
            do {
                let status = try await servicesStore.testConnection(
                    baseURL: baseURL,
                    endpoints: endpoints,
                    auth: auth,
                    tokenOverride: tokenOverride,
                    storedTokenFor: existing?.id
                )
                await MainActor.run {
                    let state = ServiceState.from(status)
                    let memory = status.memory.map { memory -> String in
                        memory.available ? Formatters.formatByteCount(memory.totalRssBytes) : "—"
                    } ?? "—"
                    testResult = .success(
                        "Connected: \(state.label)"
                        + (status.pid.map { ", pid \($0)" } ?? "")
                        + ", memory \(memory)."
                    )
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTesting = false
                }
            }
        }
    }

    private func applyManifestLine() {
        do {
            guard let manifest = try parseManifestInput() else {
                testResult = .failure("Paste a manifest line first.")
                return
            }
            parsedManifest = manifest
            testResult = .success(
                "Manifest loaded: \(manifest.service.name) \(manifest.service.version ?? ""), "
                + "\(manifest.baseURL.absoluteString)."
            )
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }

    private func parseManifestInput() throws -> ServiceManifest? {
        let value = manifestLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("{") {
            return try ServiceManifestParser.parse(line: "\(ServiceManifestParser.prefix) \(value)")
        }
        return try ServiceManifestParser.parse(line: value)
    }

    // MARK: - Helpers

    private var storedToken: Bool {
        guard let existing else { return false }
        return servicesStore.hasToken(for: existing.id)
    }

    /// `nil` keeps the stored token, `""` removes it, any other value replaces it.
    private var tokenOverride: String? {
        guard existing != nil else {
            return token.isEmpty ? nil : token
        }
        if !token.isEmpty {
            return token
        }
        return removesStoredToken ? "" : nil
    }

    private var tokenHint: String {
        if storedToken {
            if removesStoredToken {
                return "The stored token will be removed on save."
            }
            if !token.isEmpty {
                return "The new token will replace the stored one."
            }
            return "A token is stored in the Keychain."
        }

        return token.isEmpty
            ? "Leave empty if the service doesn't need a token."
            : "The token will be stored in the Keychain."
    }

    private var effectiveBaseURL: URL? {
        if let parsedManifest {
            return parsedManifest.baseURL
        }
        if let pasted = try? parseManifestInput() {
            return pasted.baseURL
        }
        return existing?.baseURL
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
