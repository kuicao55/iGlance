import SwiftUI

struct SectionSwitcherButton: View {
    let section: AppSection
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: section.sfSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(height: 20)

                Text(section.displayName)
                    .font(.caption)
            }
            // The whole tab is a hit target, not just the symbol.
            .frame(maxWidth: .infinity, minHeight: 46)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Design.Radius.chip, style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: Design.Radius.chip, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
            }
            .contentShape(.rect(cornerRadius: Design.Radius.chip))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .animation(Design.Motion.hover, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(section.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
