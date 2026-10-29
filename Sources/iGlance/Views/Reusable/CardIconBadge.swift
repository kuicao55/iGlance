import SwiftUI

/// The small tinted glyph badge shared by the monitor cards.
struct CardIconBadge: View {
    let systemName: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32)
                .fill(.thinMaterial)

            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
