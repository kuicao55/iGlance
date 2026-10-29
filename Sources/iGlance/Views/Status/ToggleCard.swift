import SwiftUI

struct ToggleCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        CardSurfaceView {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(Design.Spacing.cardContent)
        }
    }
}
