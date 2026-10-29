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

    @Published var name: String
    @Published var startCommand: String
    @Published var token = ""
    @Published var removesStoredToken = false
    @Published var refreshSeconds: Double
    @Published var approved: Bool
    @Published var manifestLine = ""
    @Published var parsedManifest: ServiceManifest?
    @Published var showsManifest = false
    @Published var isTesting = false
    @Published var testResult: TestResult?

    init(mode: Mode, binding: ServiceBinding?) {
        self.mode = mode
        self.name = binding?.name ?? ""
        self.startCommand = binding?.startCommand ?? ""
        self.refreshSeconds = binding?.refreshSeconds ?? 5
        self.approved = binding?.startCommandApproved ?? true
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
}
