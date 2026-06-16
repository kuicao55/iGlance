import SwiftUI

struct ColorInterpolation {
    /// Interpolate color based on value (0-100)
    /// Low (0-30): muted green
    /// Medium (30-70): soft yellow
    /// High (70-100): muted red
    static func color(for value: Double) -> Color {
        let normalized = min(max(value, 0), 100) / 100.0

        switch normalized {
        case ..<0.3:
            // Green to Yellow
            let t = normalized / 0.3
            return Color(
                red: 0.2 + t * 0.6,
                green: 0.7 + t * 0.1,
                blue: 0.3 - t * 0.2
            )
        case 0.3..<0.7:
            // Yellow to Orange
            let t = (normalized - 0.3) / 0.4
            return Color(
                red: 0.8 + t * 0.1,
                green: 0.8 - t * 0.2,
                blue: 0.1 - t * 0.05
            )
        default:
            // Orange to Red
            let t = (normalized - 0.7) / 0.3
            return Color(
                red: 0.9,
                green: 0.6 - t * 0.35,
                blue: 0.05 - t * 0.03
            )
        }
    }

    /// Interpolate between two colors
    static func interpolate(from: Color, to: Color, progress: Double) -> Color {
        let t = min(max(progress, 0), 1)

        // Convert to NSColor for component extraction
        let fromNS = NSColor(from)
        let toNS = NSColor(to)

        var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
        var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0

        fromNS.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        toNS.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

        return Color(
            red: Double(fromR + (toR - fromR) * t),
            green: Double(fromG + (toG - fromG) * t),
            blue: Double(fromB + (toB - fromB) * t),
            opacity: Double(fromA + (toA - fromA) * t)
        )
    }
}
