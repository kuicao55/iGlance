import Foundation

struct MemorySnapshot {
    let usage: Double  // 0-100 percentage
    let usedMemoryGB: Double?
    let totalMemoryGB: Double?
    let pressure: String  // "Normal", "Warning", "Critical"
    let topProcesses: [ProcessMetric]
    let isAvailable: Bool

    static var unavailable: MemorySnapshot {
        MemorySnapshot(usage: 0, usedMemoryGB: nil, totalMemoryGB: nil, pressure: "Unknown", topProcesses: [], isAvailable: false)
    }
}
