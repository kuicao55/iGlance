import SwiftUI

struct TemperatureCardView: View {
    let snapshot: TemperatureSnapshot

    var body: some View {
        CardSurfaceView {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)

                ZStack(alignment: .topTrailing) {
                    // Same structure as the metric cards: the data block fills
                    // the space above the footer, so every card's title sits on
                    // the same baseline.
                    VStack(spacing: 8) {
                        VStack(spacing: 8) {
                            TemperatureBarView(label: "CPU", value: snapshot.cpu, maxValue: 100)
                            TemperatureBarView(label: "GPU", value: snapshot.gpu, maxValue: 100)
                            TemperatureBarView(label: "Battery", value: snapshot.battery, maxValue: 100)
                        }
                        .offset(y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                        footer
                    }
                    .padding(Design.Spacing.cardContent)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    CardIconBadge(systemName: "thermometer.medium", tint: .mint, size: side * 0.115)
                        .padding(12)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Temperature")
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Label("TEMPERATURE", systemImage: "thermometer.medium")
                .font(Design.Typography.cardTitle)
                .foregroundStyle(.primary)

            Text(snapshot.isAvailable ? "Live" : "Unavailable")
                .font(Design.Typography.cardDetail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
