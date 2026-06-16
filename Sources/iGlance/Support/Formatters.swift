import Foundation

struct Formatters {
    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let temperature: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let memory: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
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
}
