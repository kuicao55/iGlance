import SwiftUI

struct MonitorView: View {
    @ObservedObject var monitorStore: MonitorStore

    /// Height of the title/subtitle block above the card grid.
    private let headerHeight: CGFloat = 42

    var body: some View {
        GeometryReader { proxy in
            let page = Design.Spacing.page
            let spacing = Design.Spacing.section
            let contentWidth = max(proxy.size.width - page * 2, 0)
            let contentHeight = max(proxy.size.height - page * 2 - headerHeight - spacing, 0)
            let cardSize = max(min((contentWidth - spacing) / 2, contentHeight / 2), 0)

            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    MonitorHeaderView(loadIndex: monitorStore.loadIndex)
                        .frame(height: headerHeight, alignment: .top)

                    MonitorGridView(
                        monitorStore: monitorStore,
                        cardSize: cardSize,
                        spacing: spacing
                    )
                }
                .padding(page)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
