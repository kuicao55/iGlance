import Foundation

struct TemperatureSnapshot {
    let cpu: Double?  // Celsius
    let gpu: Double?  // Celsius
    let battery: Double?  // Celsius
    let isAvailable: Bool

    static var unavailable: TemperatureSnapshot {
        TemperatureSnapshot(cpu: nil, gpu: nil, battery: nil, isAvailable: false)
    }

    var maxTemperature: Double {
        [cpu, gpu, battery].compactMap { $0 }.max() ?? 0
    }
}
