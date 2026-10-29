import SwiftUI

struct TemperatureBarView: View {
    let label: String
    let value: Double?
    let maxValue: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(label: String, value: Double?, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
                .lineLimit(1)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor(for: value ?? 0))
                    .scaleEffect(x: normalizedValue, y: 1, anchor: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 8)
            .animation(reduceMotion ? nil : Design.Motion.bar, value: value)

            Text(Formatters.formatTemperature(value))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
                .lineLimit(1)
        }
    }

    private var normalizedValue: CGFloat {
        CGFloat(min(max((value ?? 0) / maxValue, 0), 1))
    }

    private func barColor(for temp: Double) -> Color {
        switch temp {
        case ..<45: .green
        case 45..<70: .yellow
        case 70..<85: .orange
        default: .red
        }
    }
}
