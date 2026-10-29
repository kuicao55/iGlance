import SwiftUI

struct OpenArcGaugeView: View {
    let value: Double
    let color: Color
    let label: String
    let subtitle: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineWidth: CGFloat = 8.5
    private let bottomGap: CGFloat = 60  // degrees

    init(value: Double, color: Color, label: String, subtitle: String? = nil) {
        self.value = min(max(value, 0), 100)
        self.color = color
        self.label = label
        self.subtitle = subtitle
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let gaugeSize = max(size - 4, 0)

            ZStack {
                ArcShape(startAngle: .degrees(90 + bottomGap / 2), endAngle: .degrees(90 - bottomGap / 2 + 360))
                    .stroke(
                        .quaternary,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

                ArcShape(
                    startAngle: .degrees(90 + bottomGap / 2),
                    endAngle: .degrees(90 + bottomGap / 2 + arcAngle)
                )
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .animation(reduceMotion ? nil : Design.Motion.gauge, value: value)

                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: size * 0.21, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 2)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: size * 0.1, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: gaugeSize * 0.82, height: gaugeSize * 0.82, alignment: .center)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var arcAngle: Double {
        // Convert 0-100 to degrees (max 300 degrees)
        return (value / 100.0) * (360.0 - bottomGap)
    }
}

struct ArcShape: Shape {
    var startAngle: Angle
    var endAngle: Angle

    /// Interpolating the angles is what makes the gauge sweep instead of
    /// snapping when the value changes.
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(min(rect.width, rect.height) / 2 - 5, 0)

        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}
