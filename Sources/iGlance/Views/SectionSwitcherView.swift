import SwiftUI

struct SectionSwitcherView: View {
    @Binding var activeSection: AppSection
    let hasUpdate: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        switcherBar
    }

    @ViewBuilder
    private var switcherBar: some View {
        let bar = HStack(spacing: 6) {
            ForEach(AppSection.allCases, id: \.self) { section in
                SectionSwitcherButton(
                    section: section,
                    isSelected: activeSection == section,
                    showsBadge: section == .settings && hasUpdate,
                    namespace: selectionNamespace,
                    action: { select(section) }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)

        if #available(macOS 26.0, *) {
            bar.glassEffect(.regular, in: .rect(cornerRadius: Design.Radius.panel))
        } else {
            bar
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.panel, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Design.Radius.panel, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                }
        }
    }

    private func select(_ section: AppSection) {
        guard section != activeSection else { return }

        if reduceMotion {
            activeSection = section
        } else {
            withAnimation(Design.Motion.selection) {
                activeSection = section
            }
        }
    }
}
