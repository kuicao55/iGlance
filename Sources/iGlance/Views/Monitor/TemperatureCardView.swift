import SwiftUI

struct TemperatureCardView: View {
    let snapshot: TemperatureSnapshot

    var body: some View {
        CardSurfaceView {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let inset = side * 0.072
                let iconSize = side * 0.13
                let rowSpacing = side * 0.045
                let statusHeight = side * 0.11
                let barsHeight = side * 0.36
                let noteHeight = side * 0.12

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: iconSize * 0.32, style: .continuous)
                                .fill(.thinMaterial)
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: iconSize * 0.42, weight: .semibold))
                                .foregroundStyle(.mint)
                        }
                        .frame(width: iconSize, height: iconSize)
                    }

                    Spacer(minLength: rowSpacing)

                    HStack(alignment: .firstTextBaseline) {
                        Label("TEMPERATURE", systemImage: "thermometer.medium")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Spacer()
                        Text(snapshot.isAvailable ? "Live" : "No Feed")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: statusHeight, alignment: .center)

                    Spacer(minLength: rowSpacing)

                    VStack(spacing: rowSpacing * 0.9) {
                        TemperatureBarView(
                            label: "CPU",
                            value: snapshot.cpu,
                            maxValue: 100
                        )

                        TemperatureBarView(
                            label: "GPU",
                            value: snapshot.gpu,
                            maxValue: 100
                        )

                        TemperatureBarView(
                            label: "Battery",
                            value: snapshot.ssd,
                            maxValue: 100
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: barsHeight, maxHeight: barsHeight, alignment: .center)

                    Spacer(minLength: rowSpacing * 0.8)

                    Group {
                        if !snapshot.isAvailable {
                            Text("This Mac is not exposing CPU/GPU temperature sensors to the app right now.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: noteHeight, maxHeight: noteHeight, alignment: .topLeading)
                }
                .padding(inset)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Temperature Card")
    }
}
