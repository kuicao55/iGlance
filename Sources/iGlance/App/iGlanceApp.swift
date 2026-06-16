import SwiftUI
import AppKit

@main
struct iGlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // A menu bar app does not need a SwiftUI-managed scene, but we keep an
    // empty Settings scene so AppKit still constructs a proper NSApplication
    // and routes lifecycle calls (applicationWillFinishLaunching /
    // applicationDidFinishLaunching) to our AppDelegate.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Optional strong reference to the full architecture. If the comprehensive
    // StatusItemController wires up successfully we use that; otherwise we fall
    // back to a minimal hand-rolled status item so the user can at least see
    // the icon in the menu bar.
    private var environment: AppEnvironment?
    private var statusItemController: StatusItemController?

    private var fallbackStatusItem: NSStatusItem?
    private var hasShownFirstLaunchHint = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // IMPORTANT: set the activation policy BEFORE creating any status item.
        // Doing it after can produce a status item the system refuses to draw
        // in the visible menu bar.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("iGlance: applicationDidFinishLaunching start")
        // Prefer the full architecture. If anything in the dependency graph
        // throws at construction time we fall back to a simple status item so
        // the app is still observable from the menu bar.
        let env: AppEnvironment
        do {
            env = AppEnvironment()
            NSLog("iGlance: AppEnvironment initialized")
        }
        self.environment = env

        let controller = StatusItemController(environment: env)
        NSLog("iGlance: StatusItemController created, item length=\(controller.getStatusItem().length)")
        self.statusItemController = controller
        env.monitorStore.startDetailedRefresh()

        // macOS 26 (Tahoe) hides third-party menu bar items in a hidden
        // overflow area by default. Surface a one-time hint so the user
        // knows where to look.
        showFirstLaunchHintIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.monitorStore.stopDetailedRefresh()
        environment?.statusStore.cleanup()
        statusItemController = nil
        environment = nil
        if let item = fallbackStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            fallbackStatusItem = nil
        }
    }

    // MARK: - Fallback status item

    private func installFallbackStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }

        // Always set a title as a fallback so the button is at least
        // visible if the SF Symbol can't be loaded.
        button.title = " iG "

        if let image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "iGlance") {
            button.image = image
            button.imagePosition = .imageLeft
        }
        button.image?.isTemplate = true
        button.toolTip = "iGlance — System Monitor"
        button.target = self
        button.action = #selector(fallbackClicked(_:))

        fallbackStatusItem = item
    }

    @objc private func fallbackClicked(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "iGlance"
        alert.informativeText = "The full popover UI failed to initialize, so the fallback menu bar item is shown. Check the Console.app log for details."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - First-launch hint

    private func showFirstLaunchHintIfNeeded() {
        let key = "iGlance.didShowFirstLaunchHint.v1"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)

        // Defer to next runloop so the menu bar has a chance to draw.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, !self.hasShownFirstLaunchHint else { return }
            self.hasShownFirstLaunchHint = true
            self.presentFirstLaunchHint()
        }
    }

    private func presentFirstLaunchHint() {
        let alert = NSAlert()
        alert.messageText = "iGlance is running"
        alert.informativeText = """
        iGlance lives in the menu bar. On macOS 26 (Tahoe) the icon may be hidden in the menu bar overflow area on first install.

        • Open System Settings → Menu Bar
        • Or click the date/time area of the menu bar to reveal hidden icons
        • Drag the iGlance icon into the visible menu bar to pin it

        You can dismiss this message — iGlance is running either way.
        """
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "Dismiss")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.menuBar") {
            NSWorkspace.shared.open(url)
        }
    }
}
