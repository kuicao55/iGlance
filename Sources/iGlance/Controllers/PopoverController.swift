import AppKit
import SwiftUI
import Combine

class PopoverController: NSObject {
    private let popover: NSPopover
    private let environment: AppEnvironment
    private(set) var isShown = false
    private var outsideClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment) {
        self.environment = environment
        self.popover = NSPopover()

        super.init()

        setupPopover()
        observeServiceEditor()
    }

    private func setupPopover() {
        let popoverView = PopoverView(environment: environment)
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.view.appearance = NSApp.effectiveAppearance

        popover.contentSize = NSSize(
            width: Design.Layout.popoverWidth,
            height: Design.Layout.popoverHeight
        )
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.appearance = NSApp.effectiveAppearance
        popover.contentViewController = hostingController
    }

    func show(relativeTo button: NSButton) {
        environment.monitorStore.startDetailedRefresh()
        environment.statusStore.refreshSleepDisabledStatus()
        if environment.appStore.activeSection == .services {
            environment.servicesStore.startPolling()
        }
        Task { await environment.updateStore.checkIfNeeded() }

        applyInteractionBehavior()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.appearance = NSApp.effectiveAppearance
        popover.contentViewController?.view.window?.isOpaque = false
        popover.contentViewController?.view.window?.backgroundColor = .clear
        isShown = true
        environment.appStore.popoverDidOpen()
        applyInteractionBehavior()
    }

    /// While the service editor is open the popover has to survive a trip to
    /// another app (to copy a command or token), so it stops closing on outside
    /// clicks. The menu bar icon still toggles it closed.
    private func observeServiceEditor() {
        environment.servicesStore.$editor
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyInteractionBehavior()
            }
            .store(in: &cancellables)
    }

    private func applyInteractionBehavior() {
        let isEditing = environment.servicesStore.editor != nil
        popover.behavior = isEditing ? .applicationDefined : .transient
        guard isShown else { return }

        if isEditing {
            removeOutsideClickMonitor()
        } else if outsideClickMonitor == nil {
            installOutsideClickMonitor()
        }
    }

    func close() {
        popover.performClose(nil)
        isShown = false
        environment.appStore.popoverDidClose()
        environment.monitorStore.stopDetailedRefresh()
        environment.servicesStore.stopPolling()
        removeOutsideClickMonitor()
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isShown else { return }
            guard let window = self.popover.contentViewController?.view.window else { return }
            if !window.frame.contains(NSEvent.mouseLocation) {
                self.close()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}

extension PopoverController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        isShown = false
        environment.appStore.popoverDidClose()
        environment.monitorStore.stopDetailedRefresh()
        environment.servicesStore.stopPolling()
        removeOutsideClickMonitor()
    }
}
