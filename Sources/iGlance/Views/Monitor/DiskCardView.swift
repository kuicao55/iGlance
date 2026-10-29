import SwiftUI

struct DiskCardView: View {
    let snapshot: DiskSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MetricFrontCardView(icon: "internaldrive", tint: .orange) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let barWidth = width * 0.72
                let barHeight = width * 0.08
                let fill = min(max(snapshot.usage / 100, 0), 1)

                VStack(spacing: width * 0.08) {
                    Text(snapshot.isAvailable ? Formatters.formatPercentage(snapshot.usage) : "N/A")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: barHeight / 2)
                            .fill(.orange)
                            .scaleEffect(x: CGFloat(fill), y: 1, anchor: .leading)
                            .animation(reduceMotion ? nil : Design.Motion.bar, value: snapshot.usage)
                    }
                    .frame(width: barWidth, height: barHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } footer: {
            VStack(spacing: 4) {
                Label {
                    Text("DISK")
                        .font(Design.Typography.cardTitle)
                        .tracking(0.4)
                } icon: {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.primary)

                if let used = snapshot.usedSpaceGB, let total = snapshot.totalSpaceGB {
                    Text("\(used, format: .number.precision(.fractionLength(0))) of \(total, format: .number.precision(.fractionLength(0))) GB")
                        .font(Design.Typography.cardDetail)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(snapshot.volumeName)
                        .font(Design.Typography.cardDetail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Disk")
    }
}
