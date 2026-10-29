import SwiftUI

struct StatusView: View {
    @ObservedObject var statusStore: StatusStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.section) {
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
                            .foregroundStyle(.orange)
                            .font(.headline)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Sleep Disabled")
                                .font(.headline)
                            Text("Read-only system-level state")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        SleepStatusIndicator(isDisabled: statusStore.assertionState.systemSleepDisabled)
                    }
                    .padding(Design.Spacing.cardContent)
                }
            }
            .padding(Design.Spacing.page)
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
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }
}
