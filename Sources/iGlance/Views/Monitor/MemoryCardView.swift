import SwiftUI

struct MemoryCardView: View {
    let snapshot: MemorySnapshot
    let history: [Double]
    @Binding var isFlipped: Bool

    var body: some View {
        FlippableCard(
            isFlipped: $isFlipped,
            accessibilityLabel: "Memory",
            accessibilityHint: "Shows top processes"
        ) {
            MonitorCardView(isFlipped: isFlipped) {
                MetricFrontCardView(icon: "memorychip", tint: .yellow) {
                    OpenArcGaugeView(
                        value: snapshot.usage,
                        color: ColorInterpolation.color(for: snapshot.usage),
                        label: Formatters.formatPercentage(snapshot.usage)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } footer: {
                    VStack(spacing: 4) {
                        Label("MEMORY", systemImage: "memorychip")
                            .font(Design.Typography.cardTitle)
                            .foregroundStyle(.primary)

                        if let used = snapshot.usedMemoryGB, let total = snapshot.totalMemoryGB {
                            Text("\(Formatters.formatMemoryGB(used)) of \(Formatters.formatMemoryGB(total))")
                                .font(Design.Typography.cardDetail)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(snapshot.pressure)
                                .font(Design.Typography.cardDetail)
                                .foregroundStyle(pressureColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } back: {
                CardSurfaceView {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Top Processes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        SparklineView(values: history, color: .green)
                            .frame(height: 34)

                        if snapshot.topProcesses.isEmpty {
                            Text("Process access unavailable")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(snapshot.topProcesses.prefix(5)) { process in
                                HStack {
                                    Text(process.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(Formatters.formatMemoryGB(process.value / 1_048_576.0))
                                        .font(.caption2)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(Design.Spacing.cardContent)
                }
            }
        }
    }

    private var pressureColor: Color {
        switch snapshot.pressure {
        case "Critical": .red
        case "Warning": .orange
        case "Normal": .green
        default: .secondary
        }
    }
}
