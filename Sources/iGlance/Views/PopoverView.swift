import SwiftUI

struct PopoverView: View {
    @ObservedObject var appStore: AppStore
    @ObservedObject var monitorStore: MonitorStore
    @ObservedObject var statusStore: StatusStore
    @ObservedObject var servicesStore: ServicesStore
    @ObservedObject var updateStore: UpdateStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsUpdatePanel = false

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
                    isUpdateActive: showsUpdatePanel,
                    updateIsBusy: updateStore.isBusy,
                    hasUpdate: updateStore.hasUpdate,
                    onUpdate: toggleUpdatePanel,
                    onSectionSelect: { _ in dismissUpdatePanel() }
                )
                .padding(.horizontal, Design.Spacing.page)
                .padding(.vertical, Design.Spacing.page)

                Divider()

                ZStack {
                    if showsUpdatePanel {
                        UpdatePanelView(store: updateStore, onClose: closeUpdatePanel)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    } else {
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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: Design.Layout.popoverWidth, height: Design.Layout.popoverHeight)
        .onChange(of: appStore.activeSection) { _, section in
            showsUpdatePanel = false
            if section == .services {
                servicesStore.startPolling()
            } else {
                servicesStore.stopPolling()
            }
        }
        .onDisappear {
            showsUpdatePanel = false
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
        }
    }

    private func toggleUpdatePanel() {
        if reduceMotion {
            showsUpdatePanel.toggle()
        } else {
            withAnimation(Design.Motion.section) {
                showsUpdatePanel.toggle()
            }
        }
    }

    private func dismissUpdatePanel() {
        guard showsUpdatePanel else { return }
        closeUpdatePanel()
    }

    private func closeUpdatePanel() {
        if reduceMotion {
            showsUpdatePanel = false
        } else {
            withAnimation(Design.Motion.section) {
                showsUpdatePanel = false
            }
        }
    }
}
