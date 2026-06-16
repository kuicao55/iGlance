import SwiftUI

struct TemperatureBarView: View {
    let label: String
    let value: Double?
    let maxValue: Double

    init(label: String, value: Double?, maxValue: Double = 100) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    if let value = value {
                        let normalized = min(value / maxValue, 1.0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(for: value))
                            .frame(width: geometry.size.width * normalized, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: value)
                    }
                }
            }
            .frame(height: 8)

            if let value = value {
                Text(Formatters.formatTemperature(value))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            } else {
                Text("N/A")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 45, alignment: .trailing)
            }
        }
    }

    private func barColor(for temp: Double) -> Color {
        switch temp {
        case ..<45:
            return .green
        case 45..<70:
            return .yellow
        case 70..<85:
            return .orange
        default:
            return .red
        }
    }
}
