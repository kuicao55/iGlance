import Foundation

class GPUUsageProvider {
    private let processRunner = ProcessRunner()
    private var previousUsage: Double = 0
    private lazy var cachedDeviceDetails: (name: String?, coreCount: Int?) = loadDeviceDetails()

    func currentUsage() -> Double {
        let sources = [
            "ioreg -r -l -w 0 -c AGXAccelerator 2>/dev/null | grep -E 'PerformanceStatistics|In use system memory|Alloc system memory|Device Utilization %|Renderer Utilization %|Tiler Utilization %'",
            "ioreg -r -l -w 0 2>/dev/null | grep -Ei 'GPU.*(Utilization|Usage|Percentage)|GPURaw|GPUCore' | head -n 20",
            "powermetrics --samplers gpu_power -n 1 2>/dev/null"
        ]

        for command in sources {
            let result = processRunner.runShell(command)
            guard result.terminationStatus == 0, !result.stdout.isEmpty else { continue }

            if let usage = parseUsage(from: result.stdout) {
                previousUsage = usage
                return usage
            }
        }

        return previousUsage > 0 ? previousUsage : -1
    }

    func vramUsage() -> (used: Double?, total: Double?) {
        if let fromIOReg = parseSharedMemoryUsage() {
            return fromIOReg
        }

        let result = processRunner.runShell("system_profiler SPDisplaysDataType 2>/dev/null")
        guard result.terminationStatus == 0, !result.stdout.isEmpty else {
            return (nil, nil)
        }

        var total: Double?
        let lines = result.stdout.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()
            guard lower.contains("vram") else { continue }

            guard let raw = parseFirstNumber(from: line) else { continue }

            if lower.contains("gb") {
                total = raw
            } else if lower.contains("mb") {
                total = raw / 1024.0
            }
        }

        return (nil, total)
    }

    func deviceName() -> String? {
        cachedDeviceDetails.name
    }

    func coreCount() -> Int? {
        cachedDeviceDetails.coreCount
    }

    private func parseUsage(from output: String) -> Double? {
        if let performanceStatsUsage = parsePerformanceStatisticsUsage(from: output) {
            return performanceStatsUsage
        }

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let lower = line.lowercased()
            if lower.contains("utilization") || lower.contains("usage") || lower.contains("load") || lower.contains("gpuraw") || lower.contains("gpucore") {
                if let percent = parsePercent(from: line) {
                    return percent
                }
            }

            if lower.contains("device utilization") || lower.contains("renderer utilization") {
                if let percent = parseFirstNumber(from: line) {
                    return percent
                }
            }

            if lower.contains("gpu") && (lower.contains("utilization") || lower.contains("usage") || lower.contains("load")) {
                if let percent = parsePercent(from: line) {
                    return percent
                }
            }

            if let percent = parsePercent(from: line) {
                return percent
            }

            if lower.contains("gpu"), let numeric = parseFirstNumber(from: line), numeric >= 0 {
                if numeric <= 1.0, lower.contains("util") || lower.contains("usage") || lower.contains("load") {
                    return min(numeric * 100.0, 100.0)
                }

                if numeric <= 100.0 {
                    return numeric
                }
            }
        }

        return nil
    }

    private func parsePerformanceStatisticsUsage(from output: String) -> Double? {
        let patterns = [
            #""Device Utilization %"\s*=\s*(\d+(?:\.\d+)?)"#,
            #""Renderer Utilization %"\s*=\s*(\d+(?:\.\d+)?)"#,
            #""Tiler Utilization %"\s*=\s*(\d+(?:\.\d+)?)"#
        ]

        for pattern in patterns {
            if let value = parseFirstCapture(in: output, pattern: pattern) {
                return min(max(value, 0), 100)
            }
        }

        return nil
    }

    private func parsePercent(from line: String) -> Double? {
        if let range = line.range(of: #"\d+(?:\.\d+)?%"#, options: .regularExpression) {
            let value = line[range].replacingOccurrences(of: "%", with: "")
            return Double(value)
        }

        return nil
    }

    private func parseFirstNumber(from line: String) -> Double? {
        if let range = line.range(of: #"\d+(?:\.\d+)?"#, options: .regularExpression) {
            return Double(line[range])
        }
        return nil
    }

    private func parseSharedMemoryUsage() -> (used: Double?, total: Double?)? {
        let result = processRunner.runShell(
            "ioreg -r -l -w 0 -c AGXAccelerator 2>/dev/null | grep -E 'PerformanceStatistics|In use system memory|Alloc system memory'"
        )
        guard result.terminationStatus == 0, !result.stdout.isEmpty else {
            return nil
        }

        let usedBytes = parseFirstCapture(in: result.stdout, pattern: #""In use system memory"\s*=\s*(\d+(?:\.\d+)?)"#)
        let totalBytes = parseFirstCapture(in: result.stdout, pattern: #""Alloc system memory"\s*=\s*(\d+(?:\.\d+)?)"#)

        guard usedBytes != nil || totalBytes != nil else {
            return nil
        }

        return (
            used: usedBytes.map { $0 / 1_073_741_824.0 },
            total: totalBytes.map { $0 / 1_073_741_824.0 }
        )
    }

    private func loadDeviceDetails() -> (name: String?, coreCount: Int?) {
        let ioreg = processRunner.runShell(
            "ioreg -r -l -w 0 -c AGXAccelerator 2>/dev/null | grep -E '\"model\"|\"gpu-core-count\"' | head -n 6"
        )

        var name: String?
        var coreCount: Int?

        if ioreg.terminationStatus == 0, !ioreg.stdout.isEmpty {
            name = parseFirstStringCapture(in: ioreg.stdout, pattern: #""model"\s*=\s*"([^"]+)""#)

            if let coreValue = parseFirstCapture(in: ioreg.stdout, pattern: #""gpu-core-count"\s*=\s*(\d+)"#) {
                coreCount = Int(coreValue)
            }
        }

        if name == nil {
            let profiler = processRunner.runShell("system_profiler SPDisplaysDataType 2>/dev/null | head -n 40")
            if profiler.terminationStatus == 0 {
                for line in profiler.stdout.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasSuffix(":") else { continue }

                    let candidate = String(trimmed.dropLast())
                    guard !candidate.isEmpty, candidate != "Graphics/Displays" else { continue }
                    name = candidate
                    break
                }
            }
        }

        return (name, coreCount)
    }

    private func parseFirstCapture(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return Double(text[captureRange])
    }

    private func parseFirstStringCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let value = String(text[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
