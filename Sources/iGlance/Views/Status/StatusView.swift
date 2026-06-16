import SwiftUI

struct StatusView: View {
    @ObservedObject var statusStore: StatusStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                ToggleCard(
                    icon: "lock.fill",
                    tint: .blue,
                    title: "Prevent System Sleep",
                    subtitle: "Keeps your Mac awake",
                    isOn: Binding(
                        get: { statusStore.assertionState.preventSystemSleep },
                        set: { _ in statusStore.toggleSystemSleep() }
                    )
                )

                ToggleCard(
                    icon: "display",
                    tint: .green,
                    title: "Prevent Display Sleep",
                    subtitle: "Keeps your screen on",
                    isOn: Binding(
                        get: { statusStore.assertionState.preventDisplaySleep },
                        set: { _ in statusStore.toggleDisplaySleep() }
                    )
                )

                CardSurfaceView {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundColor(.orange)
                            .font(.headline)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Sleep Disabled")
                                .font(.headline)
                            Text("Read-only system-level state")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        statusIndicator
                    }
                    .padding(14)
                }
            }
            .padding(12)
        }
        .onAppear {
            statusStore.refreshSleepDisabledStatus()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Status")
                .font(.title3.weight(.semibold))
            Text("Sleep prevention and system sleep state")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 2)
    }

    private var statusIndicator: some View {
        Group {
            if let disabled = statusStore.assertionState.systemSleepDisabled {
                HStack(spacing: 6) {
                    Circle()
                        .fill(disabled ? Color.green : Color.gray.opacity(0.35))
                        .frame(width: 8, height: 8)
                    Text(disabled ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Unknown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct ToggleCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        CardSurfaceView {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.95)
            }
            .padding(14)
        }
    }
}
