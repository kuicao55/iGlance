import Foundation

enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// "v1.2.3" -> [1, 2, 3]
    static func components(of version: String) -> [Int] {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value.split(separator: ".").map { part in
            Int(part.prefix(while: { $0.isNumber })) ?? 0
        }
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(of: lhs)
        let right = components(of: rhs)

        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b {
                return a < b ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    /// Strips the leading "v" used by git tags for display.
    static func display(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value
    }
}
