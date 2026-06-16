#!/usr/bin/env swift

import AppKit

// Minimal test: just show a status bar icon

class MinimalApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Creating status item...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "◉"
            button.toolTip = "iGlance Test"
            print("Status item button created with title '◉'")
            print("Button frame: \(button.frame)")
            print("Button window: \(String(describing: button.window))")
        } else {
            print("ERROR: Could not create status item button")
        }
    }
}

let app = NSApplication.shared
let delegate = MinimalApp()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
