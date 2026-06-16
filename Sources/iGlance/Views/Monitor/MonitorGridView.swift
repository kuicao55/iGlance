import SwiftUI

struct MonitorGridView: View {
    @ObservedObject var monitorStore: MonitorStore
    let cardSize: CGFloat
    let spacing: CGFloat

    private var columns: [GridItem] {
        [
            GridItem(.fixed(cardSize), spacing: spacing, alignment: .center),
            GridItem(.fixed(cardSize), spacing: spacing, alignment: .center)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            CPUCardView(
                snapshot: monitorStore.currentSnapshot.cpu,
                history: monitorStore.cpuHistory,
                isFlipped: $monitorStore.isCPUCardFlipped
            )
            .frame(width: cardSize, height: cardSize, alignment: .center)

            MemoryCardView(
                snapshot: monitorStore.currentSnapshot.memory,
                history: monitorStore.memoryHistory,
                isFlipped: $monitorStore.isMemoryCardFlipped
            )
            .frame(width: cardSize, height: cardSize, alignment: .center)

            DiskCardView(
                snapshot: monitorStore.currentSnapshot.disk
            )
            .frame(width: cardSize, height: cardSize, alignment: .center)

            TemperatureCardView(
                snapshot: monitorStore.currentSnapshot.temperature
            )
            .frame(width: cardSize, height: cardSize, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
