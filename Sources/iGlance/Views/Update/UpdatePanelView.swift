import SwiftUI

/// Inline update UI shown in the popover content area — no separate window.
struct UpdatePanelView: View {
    @ObservedObject var store: UpdateStore
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.section) {
            header

            CardSurfaceView(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(Design.Spacing.cardContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            footer
        }
        .padding(Design.Spacing.page)
        .task {
            if case .idle = store.state {
                await store.check()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: Design.Radius.chip, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Software Update")
                    .font(.title3.weight(.semibold))
                Text("iGlance \(store.currentVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close update panel")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .checking:
            centered {
                ProgressView("Checking GitHub releases…")
                    .controlSize(.small)
            }

        case .upToDate(let latest):
            let isAhead = AppVersion.compare(store.currentVersion, latest) == .orderedDescending
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Version \(info.version) is available")
                    .font(.headline)
                Spacer()
                Text("You have \(store.currentVersion)")
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

            HStack(spacing: 8) {
                Link("View Release on GitHub", destination: info.releaseURL)
                    .font(.caption)

                Spacer()

                if info.assetURL == nil {
                    Text("This release has no ZIP asset.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func status(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    private func centered<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Check Again") {
                Task { await store.check() }
            }
            .controlSize(.small)
            .disabled(store.isBusy)

            Spacer()

            Link("Releases", destination: UpdateService.releasesPageURL)
                .font(.caption)

            if case .available(let info) = store.state {
                Button("Install Update") {
                    Task { await store.install(info) }
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(info.assetURL == nil)
            }
        }
    }
}
