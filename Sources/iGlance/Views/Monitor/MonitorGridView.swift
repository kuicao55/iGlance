import SwiftUI

struct MonitorGridView: View {
    @ObservedObject var monitorStore: MonitorStore
    let cardSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                CPUCardView(
                    snapshot: monitorStore.currentSnapshot.cpu,
                    history: monitorStore.cpuHistory,
                    isFlipped: $monitorStore.isCPUCardFlipped
                )
                .frame(width: cardSize, height: cardSize)

                MemoryCardView(
                    snapshot: monitorStore.currentSnapshot.memory,
                    history: monitorStore.memoryHistory,
                    isFlipped: $monitorStore.isMemoryCardFlipped
                )
                .frame(width: cardSize, height: cardSize)
            }

            HStack(spacing: spacing) {
                DiskCardView(snapshot: monitorStore.currentSnapshot.disk)
                    .frame(width: cardSize, height: cardSize)

                TemperatureCardView(snapshot: monitorStore.currentSnapshot.temperature)
                    .frame(width: cardSize, height: cardSize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
