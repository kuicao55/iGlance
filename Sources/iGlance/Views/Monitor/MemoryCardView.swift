import SwiftUI

struct MemoryCardView: View {
    let snapshot: MemorySnapshot
    let history: [Double]
    @Binding var isFlipped: Bool

    var body: some View {
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
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    if let used = snapshot.usedMemoryGB, let total = snapshot.totalMemoryGB {
                        Text("\(Formatters.formatMemoryGB(used)) of \(Formatters.formatMemoryGB(total))")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(snapshot.pressure)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(pressureColor)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } back: {
            CardSurfaceView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Processes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    SparklineView(values: history, color: .green)
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
                                Text(Formatters.formatMemoryGB(process.value / 1_048_576.0))
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
        .accessibilityLabel("Memory Card")
        .accessibilityHint("Tap to flip")
    }

    private var pressureColor: Color {
        switch snapshot.pressure {
        case "Critical": return .red
        case "Warning": return .orange
        case "Normal": return .green
        default: return .secondary
        }
    }
}
