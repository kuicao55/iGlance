import SwiftUI

struct PopoverView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var monitorStore: MonitorStore
    @ObservedObject var statusStore: StatusStore
    @ObservedObject var servicesStore: ServicesStore
    @ObservedObject var updateStore: UpdateStore

    init(environment: AppEnvironment) {
        self.appStore = environment.appStore
        self.monitorStore = environment.monitorStore
        self.statusStore = environment.statusStore
        self.servicesStore = environment.servicesStore
        self.updateStore = environment.updateStore
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.accentColor.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                SectionSwitcherView(
                    activeSection: $appStore.activeSection,
                    hasUpdate: updateStore.hasUpdate
                )
                .padding(.horizontal, Design.Spacing.page)
                .padding(.vertical, Design.Spacing.page)

                Divider()

                sectionContent
                    .id(appStore.activeSection)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .offset(y: 8))
                                .combined(with: .scale(scale: 0.99)),
                            removal: .opacity.combined(with: .offset(y: -4))
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: Design.Layout.popoverWidth, height: Design.Layout.popoverHeight)
        .onChange(of: appStore.activeSection) { _, section in
            if section == .services {
                servicesStore.startPolling()
            } else {
                servicesStore.stopPolling()
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch appStore.activeSection {
        case .monitor:
            MonitorView(monitorStore: monitorStore)
        case .status:
            StatusView(statusStore: statusStore)
        case .services:
            ServicesView(servicesStore: servicesStore)
        case .settings:
            SettingsView(updateStore: updateStore)
        }
    }
}
