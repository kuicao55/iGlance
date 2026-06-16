#!/usr/bin/env swift

import AppKit

class StatusBarTest: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== StatusBar Test ===")
        print("1. Creating status item...")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let item = statusItem {
            print("✓ Status item created")

            if let button = item.button {
                print("✓ Button exists")

                // Set title
                button.title = "◉"
                print("✓ Title set to '◉'")

                // Set tooltip
                button.toolTip = "iGlance Test"
                print("✓ Tooltip set")

                // Print button properties
                print("Button frame: \(button.frame)")
                print("Button bounds: \(button.bounds)")
                print("Button window: \(String(describing: button.window))")
                print("Button superview: \(String(describing: button.superview))")

                // Try setting an image
                let imageSize = NSSize(width: 18, height: 18)
                let image = NSImage(size: imageSize)
                image.lockFocus()

                let center = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)
                let radius: CGFloat = 7

                // Draw a simple circle
                let path = NSBezierPath(ovalIn: NSRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                NSColor.labelColor.setFill()
                path.fill()

                image.unlockFocus()
                image.isTemplate = true

                button.image = image
                print("✓ Image set (18x18 circle)")

                // Verify
                if let img = button.image {
                    print("✓ Button has image: \(img.size)")
                } else {
                    print("✗ Button has no image")
                }

                // Set action
                button.action = #selector(handleClick)
                button.target = self
                print("✓ Action set")

            } else {
                print("✗ Could not get button")
            }
        } else {
            print("✗ Could not create status item")
        }

        print("")
        print("=== Check your menu bar for the icon ===")
        print("Look for a circle in the top-right area")
        print("")
        print("Press Ctrl+C to exit")
    }

    @objc func handleClick() {
        print("Icon clicked!")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = StatusBarTest()
app.delegate = delegate
app.run()
