import Foundation

class TemperatureProvider {
    private let processRunner = ProcessRunner()

    func currentTemperatures() -> TemperatureSnapshot {
        let cpuTemp = readCPUTemperature()
        let gpuTemp = readGPUTemperature()
        let ssdTemp = readBatteryTemperature() ?? readSSDTemperature()

        if cpuTemp != nil || gpuTemp != nil || ssdTemp != nil {
            return TemperatureSnapshot(cpu: cpuTemp, gpu: gpuTemp, ssd: ssdTemp, isAvailable: true)
        }

        return .unavailable
    }

    private func extractTemperature(from line: String) -> Double? {
        if let range = line.range(of: "\\d+(?:\\.\\d+)?", options: .regularExpression) {
            return Double(line[range])
        }
        return nil
    }

    private func readCPUTemperature() -> Double? {
        // Try using osx-cpu-temp if available
        let result = processRunner.runShell("which osx-cpu-temp && osx-cpu-temp")
        if result.terminationStatus == 0, !result.stdout.isEmpty {
            let tempStr = result.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "°C", with: "")
                .replacingOccurrences(of: "C", with: "")
            return Double(tempStr)
        }
        return nil
    }

    private func readGPUTemperature() -> Double? {
        // GPU temperature often requires SMC access
        return nil
    }

    private func readBatteryTemperature() -> Double? {
        let result = processRunner.runShell("ioreg -r -l -w 0 -c AppleSmartBattery 2>/dev/null | grep '\"Temperature\" = ' | head -n 1")
        guard result.terminationStatus == 0, !result.stdout.isEmpty, let raw = extractTemperature(from: result.stdout) else {
            return nil
        }

        // AppleSmartBattery reports centi-degrees Celsius.
        return raw / 100.0
    }

    private func readSSDTemperature() -> Double? {
        // Try using smartctl if available
        let result = processRunner.runShell("which smartctl && sudo smartctl -A /dev/disk0 2>/dev/null | grep -i temperature")
        if result.terminationStatus == 0, !result.stdout.isEmpty {
            return extractTemperature(from: result.stdout)
        }
        return nil
    }
}
