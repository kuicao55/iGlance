import SwiftUI

struct SectionSwitcherView: View {
    @Binding var activeSection: AppSection
    let isUpdateActive: Bool
    let updateIsBusy: Bool
    let hasUpdate: Bool
    let onUpdate: () -> Void
    let onSectionSelect: (AppSection) -> Void

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
                    isSelected: !isUpdateActive && activeSection == section,
                    namespace: selectionNamespace,
                    action: { select(section) }
                )
            }

            UpdateTabButton(
                isSelected: isUpdateActive,
                isBusy: updateIsBusy,
                hasUpdate: hasUpdate,
                namespace: selectionNamespace,
                action: onUpdate
            )
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
        // Let the parent dismiss the update panel even when the tapped tab is
        // already the active section.
        onSectionSelect(section)

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
