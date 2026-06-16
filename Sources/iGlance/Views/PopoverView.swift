import SwiftUI

struct PopoverView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var monitorStore: MonitorStore
    @ObservedObject var statusStore: StatusStore
    @ObservedObject var tasksStore: TasksStore

    init(environment: AppEnvironment) {
        self.appStore = environment.appStore
        self.monitorStore = environment.monitorStore
        self.statusStore = environment.statusStore
        self.tasksStore = environment.tasksStore
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.accentColor.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                SectionSwitcherView(
                    activeSection: $appStore.activeSection
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Divider()

                Group {
                    switch appStore.activeSection {
                    case .monitor:
                        MonitorView(monitorStore: monitorStore)
                    case .status:
                        StatusView(statusStore: statusStore)
                    case .tasks:
                        TasksView(tasksStore: tasksStore)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
        .frame(width: 448, height: 588)
        .onAppear {
            monitorStore.startDetailedRefresh()
            statusStore.refreshSleepDisabledStatus()
            if appStore.activeSection == .tasks {
                tasksStore.refresh()
            }
        }
        .onDisappear {
            monitorStore.stopDetailedRefresh()
        }
        .onChange(of: appStore.activeSection) { _, section in
            if section == .tasks {
                tasksStore.refresh()
            } else if section == .status {
                statusStore.refreshSleepDisabledStatus()
            }
        }
    }
}
