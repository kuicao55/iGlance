import SwiftUI

struct MonitorView: View {
    @ObservedObject var monitorStore: MonitorStore

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 16
            let gridSpacing: CGFloat = 16
            let contentWidth = max(proxy.size.width - (horizontalPadding * 2), 0)
            let cardSize = min(max((contentWidth - gridSpacing) / 2, 0), 190)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    MonitorGridView(
                        monitorStore: monitorStore,
                        cardSize: cardSize,
                        spacing: gridSpacing
                    )
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 18)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monitor")
                    .font(.title3.weight(.semibold))
                Text("Live system load and temperature")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(monitorStore.loadIndex.rounded()))")
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text("Load Index")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
