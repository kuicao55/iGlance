import SwiftUI

struct DiskCardView: View {
    let snapshot: DiskSnapshot

    var body: some View {
        MetricFrontCardView(icon: "internaldrive", tint: .orange) {
            GeometryReader { proxy in
                let width = proxy.size.width

                VStack(spacing: width * 0.08) {
                Text(snapshot.isAvailable ? Formatters.formatPercentage(snapshot.usage) : "N/A")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                    RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                        .fill(Color.secondary.opacity(0.16))
                        .frame(height: width * 0.08)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                                .fill(Color.orange)
                                .frame(width: max(0, width * 0.72 * snapshot.usage / 100.0), height: width * 0.08)
                        }
                        .frame(width: width * 0.72)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } footer: {
            VStack(spacing: 4) {
                Label {
                    Text("DISK")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(0.4)
                } icon: {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.primary)

                if let used = snapshot.usedSpaceGB, let total = snapshot.totalSpaceGB {
                    Text("\(Int(used.rounded())) of \(Int(total.rounded())) GB")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(snapshot.volumeName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Disk Card")
    }
}
