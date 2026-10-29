import SwiftUI

/// A lightweight sparkline drawn with `Canvas`: one pass computes the scale,
/// then the same path is filled and stroked without extra layout passes.
struct SparklineView: View {
    let values: [Double]
    let color: Color

    init(values: [Double], color: Color = .blue) {
        self.values = values
        self.color = color
    }

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            guard values.count > 1 else {
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: size.height - 0.5))
                baseline.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                context.stroke(baseline, with: .color(.secondary.opacity(0.18)), lineWidth: 1)
                return
            }

            let (line, area) = Self.paths(values: values, size: size)
            context.fill(area, with: .color(color.opacity(0.10)))
            context.stroke(line, with: .color(color), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }

    private static func paths(values: [Double], size: CGSize) -> (line: Path, area: Path) {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let range = maxValue - minValue
        let stepX = size.width / CGFloat(max(values.count - 1, 1))
        let insetY = size.height * 0.1
        let drawableHeight = size.height * 0.8

        var line = Path()
        var area = Path()
        area.move(to: CGPoint(x: 0, y: size.height))

        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let normalized = range > 0 ? (value - minValue) / range : 0.5
            let y = size.height - (CGFloat(normalized) * drawableHeight + insetY)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                line.move(to: point)
            } else {
                line.addLine(to: point)
            }
            area.addLine(to: point)
        }

        area.addLine(to: CGPoint(x: size.width, y: size.height))
        area.closeSubpath()
        return (line, area)
    }
}
