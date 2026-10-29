import SwiftUI

/// The update control lives in the same segmented bar as the sections, so the
/// top of the popover is one unified control instead of a tab bar plus a
/// floating button.
struct UpdateTabButton: View {
    let isSelected: Bool
    let isBusy: Bool
    let hasUpdate: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if isBusy {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(height: 20)
                .overlay(alignment: .topTrailing) {
                    if hasUpdate && !isBusy {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                            .offset(x: 2, y: -1)
                            .accessibilityHidden(true)
                    }
                }

                Text("Update")
                    .font(.caption)
            }
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
        .help("Check for Updates")
        .accessibilityLabel("Software Update")
        .accessibilityValue(hasUpdate ? "Update available" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
