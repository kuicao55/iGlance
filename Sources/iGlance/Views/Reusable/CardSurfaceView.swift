import SwiftUI

struct CardSurfaceView<Content: View>: View {
    let content: Content
    let alignment: Alignment

    init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay { shape.fill(glassSheen) }
                }
                .overlay {
                    shape.strokeBorder(glassEdge, lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Design.Radius.card)
    }

    private var glassSheen: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.16),
                .white.opacity(0.04),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glassEdge: LinearGradient {
        LinearGradient(
            colors: [
                .white.opacity(0.40),
                .white.opacity(0.08),
                .black.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
