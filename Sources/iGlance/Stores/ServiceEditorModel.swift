import Foundation
import Combine

/// Draft state for the Add / Edit Service page.
///
/// The editor used to be a sheet attached to the popover. Closing the popover
/// while the sheet was up left the sheet window behind, which made the Services
/// pane modal and unclickable. The editor is now a page inside the pane, and
/// the draft lives here — in a store-owned object — so typing survives closing
/// the popover, switching sections, and reopening.
final class ServiceEditorModel: ObservableObject {
    enum Mode: Equatable {
        case add
        case edit(UUID)
    }

    enum TestResult: Equatable {
        case success(String)
        case failure(String)
    }

    let mode: Mode

    @Published var kind: ServiceKind
    @Published var name: String
    @Published var startCommand: String
    @Published var token = ""
    @Published var removesStoredToken = false
    @Published var refreshSeconds: Double
    @Published var approved: Bool

    // launchd
    @Published var launchdLabel: String
    @Published var readOnly: Bool

    // process
    @Published var processPattern: String
    @Published var pidFile: String

    // process / command
    @Published var statusCommand: String
    @Published var stopCommand: String

    // all kinds
    @Published var panelURL: String

    @Published var loadedLaunchdLabels: [String] = []
    @Published var isLoadingLabels = false

    @Published var manifestLine = ""
    @Published var parsedManifest: ServiceManifest?
    @Published var showsManifest = false
    @Published var isTesting = false
    @Published var testResult: TestResult?

    init(mode: Mode, binding: ServiceBinding?) {
        let kind = binding?.kind ?? .manifest
        self.mode = mode
        self.kind = kind
        self.name = binding?.name ?? ""
        self.startCommand = binding?.startCommand ?? ""
        self.refreshSeconds = binding?.refreshSeconds ?? 5
        self.approved = binding?.startCommandApproved ?? true
        self.launchdLabel = binding?.launchdLabel ?? ""
        self.readOnly = binding?.readOnly ?? (kind == .launchd)
        self.processPattern = binding?.processPattern ?? ""
        self.pidFile = binding?.pidFile ?? ""
        self.statusCommand = binding?.statusCommand ?? ""
        self.stopCommand = binding?.stopCommand ?? ""
        self.panelURL = binding?.panelURL ?? ""
    }

    var editingID: UUID? {
        if case .edit(let id) = mode { return id }
        return nil
    }

    var isEditing: Bool { editingID != nil }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedCommand: String {
        startCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedStatusCommand: String {
        statusCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedStopCommand: String {
        stopCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedLaunchdLabel: String {
        launchdLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedProcessPattern: String {
        processPattern.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedPIDFile: String {
        pidFile.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedPanelURL: String {
        panelURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the draft has enough information to be probed. Used by the
    /// editor's Test Status button.
    var isProbeable: Bool {
        switch kind {
        case .manifest:
            return true // Test Status is not offered for manifest drafts.
        case .launchd:
            return !trimmedLaunchdLabel.isEmpty
        case .process:
            return !trimmedProcessPattern.isEmpty || !trimmedPIDFile.isEmpty
        case .command:
            return !trimmedStatusCommand.isEmpty
        }
    }

    /// Everything that decides which service is controlled or executed. When
    /// this changes for an existing binding, the approval must be re-granted.
    var controlFingerprint: String {
        [
            kind.rawValue,
            startCommand,
            statusCommand,
            stopCommand,
            launchdLabel,
            processPattern,
            pidFile
        ].joined(separator: "\u{1F}")
    }

    /// A binding built from the current draft. Used for connection tests and
    /// validation without saving.
    func draftBinding(id: UUID? = nil) -> ServiceBinding {
        ServiceBinding(
            id: id ?? editingID ?? UUID(),
            name: trimmedName,
            startCommand: trimmedCommand,
            refreshSeconds: refreshSeconds,
            kind: kind,
            launchdLabel: trimmedLaunchdLabel,
            processPattern: trimmedProcessPattern,
            pidFile: trimmedPIDFile,
            readOnly: readOnly,
            statusCommand: trimmedStatusCommand,
            stopCommand: trimmedStopCommand,
            panelURL: trimmedPanelURL,
            startCommandApproved: approved
        )
    }
}
