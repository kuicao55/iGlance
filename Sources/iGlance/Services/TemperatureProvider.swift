import Foundation

class TemperatureProvider {
    private let smc = SMCTemperatureReader()
    private let hid = HIDTemperatureReader()
    private let processRunner = ProcessRunner()

    func currentTemperatures() -> TemperatureSnapshot {
        let hidReading = hid.read()
        let cpu = smc.cpuTemperature() ?? hidReading.cpu
        let gpu = smc.gpuTemperature() ?? hidReading.gpu
        let battery = hidReading.battery ?? readBatteryTemperature()

        if cpu != nil || gpu != nil || battery != nil {
            return TemperatureSnapshot(cpu: cpu, gpu: gpu, battery: battery, isAvailable: true)
        }

        return .unavailable
    }

    /// Fallback for Macs where the HID battery sensor is not exposed.
    private func readBatteryTemperature() -> Double? {
        let result = processRunner.runShell("ioreg -r -l -w 0 -c AppleSmartBattery 2>/dev/null | grep '\"Temperature\" = ' | head -n 1")
        guard result.terminationStatus == 0, !result.stdout.isEmpty,
              let range = result.stdout.range(of: "\\d+(?:\\.\\d+)?", options: .regularExpression),
              let raw = Double(result.stdout[range])
        else {
            return nil
        }

        // AppleSmartBattery reports centi-degrees Celsius.
        return raw / 100.0
    }
}
