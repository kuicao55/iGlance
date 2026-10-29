import AppKit
import Combine

/// Owns the NSStatusItem shown in the macOS menu bar and routes clicks to the
/// popover controller. The icon is updated on a 2-second loop using the
/// synthesized load index from the monitor store.
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popoverController: PopoverController
    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()
    private var iconRefreshTimer: Timer?
    private var eventMonitor: Any?
    private var lastRenderedLoadIndex: Double?

    init(environment: AppEnvironment) {
        NSLog("iGlance: StatusItemController init start")
        self.environment = environment
        // A fixed minimum width keeps the button visible even when the
        // rendered arc-gauge image is empty (a known issue on macOS 26 with
        // template NSImages produced via lockFocus).
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("iGlance: status item created, length=\(statusItem.length)")

        self.popoverController = PopoverController(environment: environment)
        NSLog("iGlance: PopoverController created")

        super.init()
        NSLog("iGlance: super.init done")

        setupStatusItem()
        NSLog("iGlance: setupStatusItem done")
        startIconRefreshLoop()
        NSLog("iGlance: startIconRefreshLoop done")
        observeLoadIndex()
        NSLog("iGlance: init end")
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        iconRefreshTimer?.invalidate()
        if let button = statusItem.button {
            button.target = nil
            button.action = nil
        }
    }

    func getStatusItem() -> NSStatusItem {
        return statusItem
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown

        let initialImage = environment.iconRenderer.renderIcon(loadIndex: 0)
        if !initialImage.representations.isEmpty {
            button.image = initialImage
            button.image?.isTemplate = true
            lastRenderedLoadIndex = 0
        }
        if button.image == nil {
            // Last-resort fallback so the slot is never blank.
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "iGlance")
            button.image?.isTemplate = true
        }

        button.toolTip = "iGlance — System Monitor"
        button.action = #selector(togglePopover)
        button.target = self

        NSLog("iGlance: button frame=\(button.frame) title='\(button.title)' imageSize=\(button.image?.size ?? .zero) reps=\(button.image?.representations.count ?? 0) statusItemVisible=\(statusItem.isVisible) menu=\(statusItem.menu == nil ? "nil" : "set")")
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popoverController.isShown {
            popoverController.close()
        } else {
            guard let button = statusItem.button else { return }
            popoverController.show(relativeTo: button)
        }
    }

    private func startIconRefreshLoop() {
        iconRefreshTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.environment.monitorStore.refreshMenuBarMetrics()
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        iconRefreshTimer = timer
        // Initial refresh
        environment.monitorStore.refreshMenuBarMetrics()
    }

    private func observeLoadIndex() {
        environment.monitorStore.$loadIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] loadIndex in
                self?.updateIcon(loadIndex: loadIndex)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(loadIndex: Double) {
        guard let button = statusItem.button else { return }

        // Re-rendering the gauge is the expensive part of the menu bar loop;
        // sub-half-point changes are not visible in the small icon.
        if let lastRenderedLoadIndex, abs(lastRenderedLoadIndex - loadIndex) < 0.5 {
            return
        }

        let rendered = environment.iconRenderer.renderIcon(loadIndex: loadIndex)
        if !rendered.representations.isEmpty {
            lastRenderedLoadIndex = loadIndex
            button.title = ""
            button.image = rendered
            button.image?.isTemplate = true
        }
    }
}
