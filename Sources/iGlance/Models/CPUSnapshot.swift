import Foundation

struct CPUSnapshot {
    let usage: Double  // 0-100
    let modelName: String
    let topProcesses: [ProcessMetric]
    let isAvailable: Bool

    static var unavailable: CPUSnapshot {
        CPUSnapshot(usage: 0, modelName: "Unknown CPU", topProcesses: [], isAvailable: false)
    }
}
