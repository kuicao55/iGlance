import SwiftUI

struct GPUCardView: View {
    let snapshot: GPUSnapshot
    let history: [Double]
    @Binding var isFlipped: Bool

    var body: some View {
        FlippableCard(
            isFlipped: $isFlipped,
            accessibilityLabel: "GPU",
            accessibilityHint: "Shows GPU history and details"
        ) {
            MonitorCardView(isFlipped: isFlipped) {
                CardSurfaceView {
                    VStack(spacing: 12) {
                        Spacer(minLength: 0)

                        OpenArcGaugeView(
                            value: snapshot.usage >= 0 ? snapshot.usage : 0,
                            color: snapshot.isAvailable ? ColorInterpolation.color(for: snapshot.usage) : .gray,
                            label: snapshot.isAvailable ? Formatters.formatPercentage(snapshot.usage) : "N/A",
                            subtitle: "GPU"
                        )
                        .frame(width: 100, height: 100)

                        if let temp = snapshot.temperature {
                            Text("GPU \(Formatters.formatTemperature(temp))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 18)
                        } else if let secondary = snapshot.secondaryDescription {
                            Text(secondary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 18)
                        } else if !snapshot.isAvailable {
                            Text("Unavailable")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 18)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(Design.Spacing.cardContent)
                }
            } back: {
                CardSurfaceView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GPU History")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        SparklineView(values: history, color: .purple)
                            .frame(height: 42)

                        if let modelName = snapshot.modelName {
                            detailRow("Chip", modelName)
                        }

                        if let coreCount = snapshot.coreCount {
                            detailRow("Cores", "\(coreCount)")
                        }

                        if let temp = snapshot.temperature {
                            detailRow("Temperature", Formatters.formatTemperature(temp))
                        }

                        if let vramDesc = snapshot.vramDescription {
                            detailRow("Memory", vramDesc)
                        } else {
                            Text("No extra GPU memory data")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(Design.Spacing.cardContent)
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
            Spacer()
            Text(value)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
