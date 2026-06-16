import Foundation

struct GPUSnapshot {
    let usage: Double  // 0-100
    let temperature: Double?  // Celsius
    let vramUsed: Double?  // GB
    let vramTotal: Double?  // GB
    let modelName: String?
    let coreCount: Int?
    let isAvailable: Bool

    static var unavailable: GPUSnapshot {
        GPUSnapshot(usage: 0, temperature: nil, vramUsed: nil, vramTotal: nil, modelName: nil, coreCount: nil, isAvailable: false)
    }

    var vramDescription: String? {
        switch (vramUsed, vramTotal) {
        case let (used?, total?):
            return String(format: "%.1f GB / %.0f GB", used, total)
        case let (used?, nil):
            return String(format: "%.1f GB shared", used)
        case let (nil, total?):
            return String(format: "%.0f GB shared", total)
        default:
            return nil
        }
    }

    var secondaryDescription: String? {
        if let vramDescription {
            return vramDescription
        }

        if let coreCount {
            return "\(coreCount) cores"
        }

        return modelName
    }
}
