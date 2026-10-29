import Foundation

struct Formatters {
    private static let relativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }

    static func formatTemperature(_ value: Double?) -> String {
        guard let value = value else { return "N/A" }
        return String(format: "%.1f°C", value)
    }

    static func formatMemory(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }

    static func formatMemoryGB(_ value: Double) -> String {
        if value >= 1.0 {
            return String(format: "%.1f GB", value)
        } else {
            return String(format: "%.0f MB", value * 1024)
        }
    }

    /// RSS values are bytes. `nil` and negative values render as an em dash
    /// so "unavailable" never looks like zero.
    static func formatByteCount(_ bytes: Int64?) -> String {
        guard let bytes, bytes >= 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    static func formatDuration(_ seconds: Double?) -> String {
        guard let seconds, seconds >= 0 else { return "—" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    static func formatRelativeDate(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "—" }
        let interval = max(0, now.timeIntervalSince(date))

        if interval < 60 {
            return "just now"
        }
        if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        }
        if interval < 86_400 {
            return "\(Int(interval / 3600))h ago"
        }

        return relativeDateFormatter.string(from: date)
    }
}
