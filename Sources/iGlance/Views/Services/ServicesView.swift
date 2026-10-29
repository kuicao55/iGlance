import SwiftUI
import AppKit

struct ServicesView: View {
    @ObservedObject var servicesStore: ServicesStore

    var body: some View {
        if let editor = servicesStore.editor {
            ServiceEditorView(model: editor, servicesStore: servicesStore)
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
                header

                if let error = servicesStore.lastActionError {
                    errorBanner(error)
                }

                if servicesStore.bindings.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: Design.Spacing.section) {
                        ForEach(servicesStore.bindings) { binding in
                            ServiceCardView(
                                binding: binding,
                                runtime: servicesStore.runtime(for: binding.id),
                                memoryHistory: servicesStore.history(for: binding.id),
                                hasToken: servicesStore.hasToken(for: binding.id),
                                panelURL: servicesStore.panelURL(for: binding.id),
                                onStart: { servicesStore.start(bindingID: binding.id) },
                                onOpenPanel: { openPanel(for: binding) },
                                onStop: { servicesStore.stop(bindingID: binding.id) },
                                onPause: { servicesStore.perform(.pause, bindingID: binding.id) },
                                onResume: { servicesStore.perform(.resume, bindingID: binding.id) },
                                onToggle: { servicesStore.perform(.toggle, bindingID: binding.id) },
                                onEdit: { servicesStore.beginEditingService(id: binding.id) },
                                onDelete: { servicesStore.deleteService(id: binding.id) }
                            )
                        }
                    }
                }

                footer
            }
            .padding(Design.Spacing.page)
        }
    }

    /// Opens the panel in the default browser. The API token is never added to
    /// the URL; the service handles its own panel login.
    private func openPanel(for binding: ServiceBinding) {
        guard let url = servicesStore.panelURL(for: binding.id) else {
            servicesStore.lastActionError = "\(binding.name) does not expose a web panel."
            return
        }
        guard NSWorkspace.shared.open(url) else {
            servicesStore.lastActionError = "Could not open \(url.absoluteString) in the default browser."
            return
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Services")
                    .font(.title3.weight(.semibold))
                Text("Headless services bound with iglance.service.v1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                servicesStore.beginAddingService()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 24)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Add Service")
            .accessibilityLabel("Add Service")
        }
    }

    private var emptyState: some View {
        CardSurfaceView {
            VStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("No services bound")
                    .font(.headline)

                Text("Add a headless service, give it a start command, and iGlance can start it, watch its memory, and stop it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Add Service") {
                    servicesStore.beginAddingService()
                }
                .controlSize(.small)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(Design.Spacing.page)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: servicesStore.isPolling ? "arrow.triangle.2.circlepath" : "pause.circle")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(servicesStore.isPolling ? "Polling while this pane is open" : "Polling paused")
                .font(.caption2)
            Spacer()
            Text("\(servicesStore.bindings.count) bound")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                servicesStore.lastActionError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: Design.Radius.chip, style: .continuous))
    }
}
