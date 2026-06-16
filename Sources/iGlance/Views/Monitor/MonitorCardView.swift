import SwiftUI

struct MonitorCardView<Front: View, Back: View>: View {
    let isFlipped: Bool
    let front: Front
    let back: Back

    init(isFlipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
    }

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
                .scaleEffect(isFlipped ? 0.98 : 1)

            back
                .opacity(isFlipped ? 1 : 0)
                .scaleEffect(isFlipped ? 1 : 0.98)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isFlipped)
    }
}
