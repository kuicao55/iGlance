import SwiftUI

struct MonitorHeaderView: View {
    let loadIndex: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monitor")
                    .font(.title3.weight(.semibold))
                Text("Live system load and temperature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(loadIndex.rounded(), format: .number.precision(.fractionLength(0)))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : Design.Motion.number, value: loadIndex.rounded())
                Text("Load Index")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
