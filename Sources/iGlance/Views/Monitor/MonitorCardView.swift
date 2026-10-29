import SwiftUI

/// Cross-fades under Reduce Motion, otherwise rotates the two faces around the
/// vertical axis so the card genuinely flips in 3D.
struct MonitorCardView<Front: View, Back: View>: View {
    let isFlipped: Bool
    let front: Front
    let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isFlipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
    }

    var body: some View {
        ZStack {
            if reduceMotion {
                front
                    .opacity(isFlipped ? 0 : 1)
                    .accessibilityHidden(isFlipped)

                back
                    .opacity(isFlipped ? 1 : 0)
                    .accessibilityHidden(!isFlipped)
            } else {
                FlipFace(angle: isFlipped ? 180 : 0, face: .front) {
                    front
                }
                .accessibilityHidden(isFlipped)

                FlipFace(angle: isFlipped ? 180 : 0, face: .back) {
                    back
                }
                .accessibilityHidden(!isFlipped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

/// Animates a single face of the flip. The face is removed from the hierarchy
/// once it turns past 90°, which gives the card a real back instead of a
/// mirrored front and avoids the hidden glass face showing through.
private struct FlipFace<Content: View>: View, Animatable {
    enum Face {
        case front
        case back
    }

    var angle: Double
    let face: Face
    let content: Content

    init(angle: Double, face: Face, @ViewBuilder content: () -> Content) {
        self.angle = angle
        self.face = face
        self.content = content()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        if isVisible {
            content
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.22
                )
                .transition(.identity)
        }
    }

    private var rotation: Double {
        face == .front ? angle : angle - 180
    }

    private var isVisible: Bool {
        switch face {
        case .front: angle < 90
        case .back: angle >= 90
        }
    }
}
