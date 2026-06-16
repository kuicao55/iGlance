import AppKit

/// Renders the dynamic menu bar icon for iGlance.
///
/// The arc gauge starts at the top, sweeps left/right symmetrically, and
/// stops with a ~60° bottom gap so it always reads as an "eye".
///
/// IMPORTANT: drawing must go through an `NSBitmapImageRep` and an explicit
/// graphics context. Creating an `NSImage(size:)` and calling `lockFocus()`
/// produces an empty bitmap on macOS 26 retina — the resulting image has a
/// representation but contains no pixels, which is why the status item
/// appeared to have no icon at all even though the NSStatusItem itself was
/// registered correctly.
final class MenuBarIconRenderer {
    private let iconSize = NSSize(width: 18, height: 18)
    private let pixelScale: CGFloat = 2  // retina
    private let pupilRadius: CGFloat = 3.0
    private let arcLineWidth: CGFloat = 1.8
    private let minArcAngle: CGFloat = 20  // degrees
    private let maxArcAngle: CGFloat = 300  // degrees
    private let bottomGap: CGFloat = 60  // degrees

    func renderIcon(loadIndex: Double) -> NSImage {
        let pixelWidth = Int(iconSize.width * pixelScale)
        let pixelHeight = Int(iconSize.height * pixelScale)

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage()
        }

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage()
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        let cg = ctx.cgContext

        // Scale so the unit-space drawing below lines up with point size.
        cg.scaleBy(x: pixelScale, y: pixelScale)

        let center = CGPoint(x: iconSize.width / 2, y: iconSize.height / 2)
        let radius = min(iconSize.width, iconSize.height) / 2 - arcLineWidth

        // Faint guide ring.
        cg.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        cg.setLineWidth(0.7)
        cg.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        cg.strokePath()

        // Pupil (fixed)
        cg.setFillColor(NSColor.black.cgColor)
        cg.addArc(center: center, radius: pupilRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        cg.fillPath()

        // Load arc (starts at 12 o'clock and grows symmetrically).
        let normalizedLoad = max(0, min(100, loadIndex))
        let arcDegrees = minArcAngle + (maxArcAngle - minArcAngle) * (normalizedLoad / 100.0)
        let arcRadians = arcDegrees * .pi / 180.0
        let halfSweep = arcRadians / 2
        let startAngle: CGFloat = .pi / 2 - halfSweep
        let endAngle: CGFloat = .pi / 2 + halfSweep

        cg.setStrokeColor(NSColor.black.cgColor)
        cg.setLineWidth(arcLineWidth)
        cg.setLineCap(.round)
        cg.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        cg.strokePath()

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: iconSize)
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
