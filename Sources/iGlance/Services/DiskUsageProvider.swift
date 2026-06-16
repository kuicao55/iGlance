import Foundation

class DiskUsageProvider {
    func currentUsage() -> DiskSnapshot {
        let rootURL = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey,
            .volumeLocalizedNameKey,
            .nameKey
        ]

        guard let values = try? rootURL.resourceValues(forKeys: keys) else {
            return .unavailable
        }

        guard let totalBytes = values.volumeTotalCapacity.map(Double.init), totalBytes > 0 else {
            return .unavailable
        }

        let availableBytes = values.volumeAvailableCapacityForImportantUsage.map(Double.init)
            ?? values.volumeAvailableCapacity.map(Double.init)
            ?? 0
        let usedBytes = max(totalBytes - availableBytes, 0)
        let usage = min(max((usedBytes / totalBytes) * 100.0, 0), 100)

        return DiskSnapshot(
            usage: usage,
            usedSpaceGB: usedBytes / 1_073_741_824.0,
            totalSpaceGB: totalBytes / 1_073_741_824.0,
            volumeName: values.volumeLocalizedName ?? values.name ?? "Macintosh HD",
            isAvailable: true
        )
    }
}
