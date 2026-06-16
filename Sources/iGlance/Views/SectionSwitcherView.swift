import SwiftUI

struct SectionSwitcherView: View {
    @Binding var activeSection: AppSection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppSection.allCases, id: \.self) { section in
                SectionSwitcherButton(
                    section: section,
                    isSelected: activeSection == section
                ) {
                    activeSection = section
                }
            }
        }
        .padding(4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
        )
    }
}

private struct SectionSwitcherButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: section.sfSymbolName)
                    .font(.system(size: 18, weight: .semibold))

                Text(section.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel(section.accessibilityLabel)
    }
}
