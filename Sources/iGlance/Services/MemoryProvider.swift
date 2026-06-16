import Foundation
import MachO

class MemoryProvider {
    private let processRunner = ProcessRunner()

    func currentUsage() -> Double {
        if let metrics = usageMetricsFromMach() {
            return metrics.usage
        }

        let result = processRunner.runShell("memory_pressure")
        guard result.terminationStatus == 0 else { return 0 }

        // Parse "System-wide memory free percentage: XX%"
        if let range = result.stdout.range(of: "free percentage: \\d+", options: .regularExpression) {
            let str = String(result.stdout[range])
            if let percentStr = str.components(separatedBy: ": ").last,
               let free = Double(percentStr) {
                return 100.0 - free
            }
        }

        // Fallback: use vm_stat
        return getUsageFromVmStat()
    }

    func usedMemoryGB() -> Double? {
        usageMetricsFromMach()?.usedMemoryGB
    }

    private func usageMetricsFromMach() -> (usage: Double, usedMemoryGB: Double)? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        guard totalBytes > 0 else { return nil }

        let appMemoryBytes = max(Double(stats.internal_page_count - stats.purgeable_count), 0) * Double(pageSize)
        let wiredBytes = Double(stats.wire_count) * Double(pageSize)
        let compressedBytes = Double(stats.compressor_page_count) * Double(pageSize)
        let usedBytes = appMemoryBytes + wiredBytes + compressedBytes
        let usage = min(max((usedBytes / totalBytes) * 100.0, 0), 100)

        return (usage, usedBytes / 1_073_741_824.0)
    }

    private func getUsageFromVmStat() -> Double {
        let result = processRunner.runShell("vm_stat")
        guard result.terminationStatus == 0 else { return 0 }

        // Parse vm_stat output
        let lines = result.stdout.components(separatedBy: "\n")
        var freePages: Double = 0
        var activePages: Double = 0
        var inactivePages: Double = 0
        var wiredPages: Double = 0

        for line in lines {
            if line.contains("page size of") {
                continue
            } else if line.contains("Pages free") {
                freePages = extractNumber(from: line)
            } else if line.contains("Pages active") {
                activePages = extractNumber(from: line)
            } else if line.contains("Pages inactive") {
                inactivePages = extractNumber(from: line)
            } else if line.contains("Pages wired") {
                wiredPages = extractNumber(from: line)
            }
        }

        let totalPages = freePages + activePages + inactivePages + wiredPages
        guard totalPages > 0 else { return 0 }

        let usedPages = activePages + wiredPages
        return (usedPages / totalPages) * 100.0
    }

    private func extractNumber(from line: String) -> Double {
        let cleaned = line.components(separatedBy: ":").last?
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".", with: "") ?? "0"
        return Double(cleaned) ?? 0
    }

    func pressureLevel() -> String {
        let result = processRunner.runShell("memory_pressure")
        guard result.terminationStatus == 0 else { return "Unknown" }

        if result.stdout.contains("critical") {
            return "Critical"
        } else if result.stdout.contains("warning") {
            return "Warning"
        }
        return "Normal"
    }

    func topProcesses(limit: Int = 5) -> [ProcessMetric] {
        let result = processRunner.runShell("ps -axo pid,rss,comm -r | head -n \(limit + 1)")
        guard result.terminationStatus == 0 else { return [] }

        var processes: [ProcessMetric] = []
        let lines = result.stdout.components(separatedBy: "\n").dropFirst()

        for (index, line) in lines.prefix(limit).enumerated() {
            let components = line
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard components.count >= 3,
                  let pid = Int32(components[0]),
                  let memoryKB = Double(components[1]) else { continue }

            let name = (components.dropFirst(2).joined(separator: " ") as NSString).lastPathComponent
            processes.append(ProcessMetric(name: name, pid: pid, value: memoryKB, ranking: index + 1))
        }

        return processes
    }
}
