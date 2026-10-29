import SwiftUI

/// Makes a whole monitor card a real button (keyboard + VoiceOver) instead of
/// a tap gesture, and respects Reduce Motion when flipping.
struct FlippableCard<Content: View>: View {
    @Binding var isFlipped: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isFlipped: Binding<Bool>,
        accessibilityLabel: String,
        accessibilityHint: String,
        @ViewBuilder content: () -> Content
    ) {
        self._isFlipped = isFlipped
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.content = content()
    }

    var body: some View {
        Button(action: toggle) {
            ZStack {
                // A hit area that never depends on the card's animated faces.
                Color.clear

                content
                    .allowsHitTesting(false)
            }
            .contentShape(.rect(cornerRadius: Design.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isFlipped ? "Details shown" : "Overview shown")
        .accessibilityHint(accessibilityHint)
    }

    private func toggle() {
        if reduceMotion {
            isFlipped.toggle()
        } else {
            withAnimation(Design.Motion.cardFlip) {
                isFlipped.toggle()
            }
        }
    }
}
