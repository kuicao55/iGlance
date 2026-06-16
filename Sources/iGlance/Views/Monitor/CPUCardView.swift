import SwiftUI

struct CPUCardView: View {
    let snapshot: CPUSnapshot
    let history: [Double]
    @Binding var isFlipped: Bool

    var body: some View {
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
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(snapshot.modelName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        } back: {
            CardSurfaceView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Processes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    SparklineView(values: history, color: .blue)
                        .frame(height: 42)

                    if snapshot.topProcesses.isEmpty {
                        Text("Process access unavailable")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(snapshot.topProcesses.prefix(5)) { process in
                            HStack {
                                Text(process.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                Text(Formatters.formatPercentage(process.value))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .onTapGesture {
            isFlipped.toggle()
        }
        .accessibilityLabel("CPU Card")
        .accessibilityHint("Tap to flip")
    }
}
