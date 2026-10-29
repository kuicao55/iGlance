import SwiftUI

struct SleepStatusIndicator: View {
    let isDisabled: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(label)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isDisabled)
        .accessibilityElement(children: .combine)
    }

    private var dotColor: Color {
        switch isDisabled {
        case true:
            return .green
        case false:
            return .secondary.opacity(0.35)
        case nil:
            return .secondary.opacity(0.2)
        }
    }

    private var label: String {
        switch isDisabled {
        case true:
            return "Enabled"
        case false:
            return "Disabled"
        case nil:
            return "Unknown"
        }
    }
}
