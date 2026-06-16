import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let color: Color

    init(values: [Double], color: Color = .blue) {
        self.values = values
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            if values.isEmpty {
                // Empty state
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            } else {
                // Sparkline
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(max(values.count - 1, 1))

                    // Find min/max for scaling
                    let maxValue = values.max() ?? 100
                    let minValue = values.min() ?? 0
                    let range = maxValue - minValue

                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = height - (CGFloat(normalizedY) * height * 0.8 + height * 0.1)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 1.5)

                // Fill gradient
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(max(values.count - 1, 1))

                    let maxValue = values.max() ?? 100
                    let minValue = values.min() ?? 0
                    let range = maxValue - minValue

                    path.move(to: CGPoint(x: 0, y: height))

                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalizedY = range > 0 ? (value - minValue) / range : 0.5
                        let y = height - (CGFloat(normalizedY) * height * 0.8 + height * 0.1)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.1))
            }
        }
    }
}
