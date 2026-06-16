import Foundation

struct TemperatureSnapshot {
    let cpu: Double?  // Celsius
    let gpu: Double?  // Celsius
    let ssd: Double?  // Celsius
    let isAvailable: Bool

    static var unavailable: TemperatureSnapshot {
        TemperatureSnapshot(cpu: nil, gpu: nil, ssd: nil, isAvailable: false)
    }

    var maxTemperature: Double {
        [cpu, gpu, ssd].compactMap { $0 }.max() ?? 0
    }
}
