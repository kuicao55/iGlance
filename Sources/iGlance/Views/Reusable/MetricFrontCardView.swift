import SwiftUI

struct MetricFrontCardView<Main: View, Footer: View>: View {
    let icon: String
    let tint: Color
    let main: Main
    let footer: Footer

    init(
        icon: String,
        tint: Color,
        @ViewBuilder main: () -> Main,
        @ViewBuilder footer: () -> Footer
    ) {
        self.icon = icon
        self.tint = tint
        self.main = main()
        self.footer = footer()
    }

    var body: some View {
        CardSurfaceView {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)

                ZStack(alignment: .topTrailing) {
                    // The icon is an overlay so it never pushes the metric and
                    // footer off-center.
                    VStack(spacing: side * 0.045) {
                        main
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                        footer
                    }
                    .padding(Design.Spacing.cardContent)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    CardIconBadge(systemName: icon, tint: tint, size: side * 0.115)
                        .padding(12)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
