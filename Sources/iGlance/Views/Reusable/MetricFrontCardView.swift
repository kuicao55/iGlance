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
                let inset = side * 0.072
                let iconSize = side * 0.13
                let interSectionSpacing = side * 0.045
                let mainSectionHeight = side * 0.48
                let footerSectionHeight = side * 0.19

                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: iconSize * 0.32, style: .continuous)
                                .fill(.thinMaterial)
                            Image(systemName: icon)
                                .font(.system(size: iconSize * 0.42, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                        .frame(width: iconSize, height: iconSize)
                    }

                    Spacer(minLength: interSectionSpacing)

                    main
                        .frame(maxWidth: .infinity, minHeight: mainSectionHeight, maxHeight: mainSectionHeight, alignment: .center)

                    Spacer(minLength: interSectionSpacing)

                    footer
                        .frame(maxWidth: .infinity, minHeight: footerSectionHeight, maxHeight: footerSectionHeight, alignment: .top)
                }
                .padding(inset)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
