import AppKit
import SwiftUI

class PopoverController: NSObject {
    private let popover: NSPopover
    private let environment: AppEnvironment
    private(set) var isShown = false
    private var outsideClickMonitor: Any?

    init(environment: AppEnvironment) {
        self.environment = environment
        self.popover = NSPopover()

        super.init()

        setupPopover()
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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.appearance = NSApp.effectiveAppearance
        popover.contentViewController?.view.window?.isOpaque = false
        popover.contentViewController?.view.window?.backgroundColor = .clear
        isShown = true
        environment.appStore.popoverDidOpen()
        installOutsideClickMonitor()
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
