import Foundation

struct DiskSnapshot {
    let usage: Double
    let usedSpaceGB: Double?
    let totalSpaceGB: Double?
    let volumeName: String
    let isAvailable: Bool

    static var unavailable: DiskSnapshot {
        DiskSnapshot(usage: 0, usedSpaceGB: nil, totalSpaceGB: nil, volumeName: "Macintosh HD", isAvailable: false)
    }
}
