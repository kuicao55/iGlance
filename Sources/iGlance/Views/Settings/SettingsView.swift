import SwiftUI
import AppKit

/// Settings is a normal section: software update plus a way out of the app.
struct SettingsView: View {
    @ObservedObject var updateStore: UpdateStore

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.section) {
            header

            CardSurfaceView(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    updateHeader
                    updateContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    updateActions
                }
                .padding(Design.Spacing.cardContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            quitCard
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Design.Spacing.page)
        .task {
            if case .idle = updateStore.state {
                await updateStore.check()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.title3.weight(.semibold))
            Text("iGlance \(updateStore.currentVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var updateHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Software Update")
                .font(.headline)

            Spacer()

            if updateStore.hasUpdate {
                Text("Available")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var updateContent: some View {
        switch updateStore.state {
        case .idle, .checking:
            centered {
                ProgressView("Checking GitHub releases…")
                    .controlSize(.small)
            }

        case .upToDate(let latest):
            let isAhead = AppVersion.compare(updateStore.currentVersion, latest) == .orderedDescending
            status(
                icon: "checkmark.seal.fill",
                tint: .green,
                title: isAhead ? "You're ahead of the latest release" : "You're up to date",
                message: isAhead
                    ? "This build is newer than the latest GitHub release (v\(latest))."
                    : "The latest GitHub release is v\(latest)."
            )

        case .available(let info):
            availableView(info)

        case .downloading:
            centered {
                ProgressView("Downloading the update…")
                    .controlSize(.small)
            }

        case .installing:
            centered {
                ProgressView("Installing and relaunching…")
                    .controlSize(.small)
            }

        case .failed(let message):
            status(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: "Update check failed",
                message: message
            )
        }
    }

    private func availableView(_ info: UpdateInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Version \(info.version) is available")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("You have \(updateStore.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if info.notes.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    Text(info.notes)
                        .font(.caption)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private var updateActions: some View {
        HStack(spacing: 8) {
            Button("Check Again") {
                Task { await updateStore.check() }
            }
            .controlSize(.small)
            .disabled(updateStore.isBusy)

            Spacer()

            Link("Releases", destination: UpdateService.releasesPageURL)
                .font(.caption)

            if case .available(let info) = updateStore.state {
                Button("Install Update") {
                    Task { await updateStore.install(info) }
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(info.assetURL == nil)
            }
        }
    }

    private var quitCard: some View {
        CardSurfaceView(alignment: .leading) {
            HStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: Design.Radius.field, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Quit iGlance")
                        .font(.subheadline.weight(.medium))
                    Text("Sleep assertions are released on exit.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
                .keyboardShortcut("q", modifiers: .command)
                .help("Quit iGlance (⌘Q)")
            }
            .padding(Design.Spacing.cardContent)
        }
    }

    @ViewBuilder
    private func centered<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func status(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }
}
