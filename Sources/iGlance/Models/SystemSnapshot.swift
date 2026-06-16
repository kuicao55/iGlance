import Foundation

struct SystemSnapshot {
    let timestamp: Date
    let cpu: CPUSnapshot
    let gpu: GPUSnapshot
    let memory: MemorySnapshot
    let disk: DiskSnapshot
    let temperature: TemperatureSnapshot
    let loadIndex: Double

    static var empty: SystemSnapshot {
        SystemSnapshot(
            timestamp: Date(),
            cpu: .unavailable,
            gpu: .unavailable,
            memory: .unavailable,
            disk: .unavailable,
            temperature: .unavailable,
            loadIndex: 0
        )
    }
}
