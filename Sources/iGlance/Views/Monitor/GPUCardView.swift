import SwiftUI

struct GPUCardView: View {
    let snapshot: GPUSnapshot
    let history: [Double]
    @Binding var isFlipped: Bool

    var body: some View {
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
                    .frame(width: 116, height: 116)

                    if let temp = snapshot.temperature {
                        Text("GPU \(Formatters.formatTemperature(temp))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 18)
                    } else if let secondary = snapshot.secondaryDescription {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 18)
                    } else if !snapshot.isAvailable {
                        Text("Unavailable")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 18)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        } back: {
            CardSurfaceView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GPU History")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    SparklineView(values: history, color: .purple)
                        .frame(height: 42)

                    if let modelName = snapshot.modelName {
                        HStack {
                            Text("Chip")
                                .font(.caption2)
                            Spacer()
                            Text(modelName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let coreCount = snapshot.coreCount {
                        HStack {
                            Text("Cores")
                                .font(.caption2)
                            Spacer()
                            Text("\(coreCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let temp = snapshot.temperature {
                        HStack {
                            Text("Temperature")
                                .font(.caption2)
                            Spacer()
                            Text(Formatters.formatTemperature(temp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let vramDesc = snapshot.vramDescription {
                        HStack {
                            Text("Memory")
                                .font(.caption2)
                            Spacer()
                            Text(vramDesc)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No extra GPU memory data")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
            }
        }
        .onTapGesture {
            isFlipped.toggle()
        }
        .accessibilityLabel("GPU Card")
        .accessibilityHint("Tap to flip")
    }
}
