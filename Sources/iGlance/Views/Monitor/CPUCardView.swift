import SwiftUI

struct CPUCardView: View {
    let snapshot: CPUSnapshot
    let history: [Double]
    @Binding var isFlipped: Bool

    var body: some View {
        FlippableCard(
            isFlipped: $isFlipped,
            accessibilityLabel: "CPU",
            accessibilityHint: "Shows top processes"
        ) {
            MonitorCardView(isFlipped: isFlipped) {
                MetricFrontCardView(icon: "cpu", tint: .green) {
                    OpenArcGaugeView(
                        value: snapshot.usage,
                        color: ColorInterpolation.color(for: snapshot.usage),
                        label: Formatters.formatPercentage(snapshot.usage)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } footer: {
                    VStack(spacing: 4) {
                        Label("CPU LOAD", systemImage: "cpu")
                            .font(Design.Typography.cardTitle)
                            .foregroundStyle(.primary)
                        Text(snapshot.modelName)
                            .font(Design.Typography.cardDetail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            } back: {
                CardSurfaceView {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Top Processes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        SparklineView(values: history, color: .blue)
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
                                    Text(Formatters.formatPercentage(process.value))
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
}
