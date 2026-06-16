import Foundation
import MachO
import Darwin

class CPUUsageProvider {
    private let processRunner = ProcessRunner()
    private var previousTotalTicks: [Int32]?
    private var previousIdleTicks: [Int32]?
    private lazy var cachedModelName: String = {
        sysctlString(named: "machdep.cpu.brand_string")
            ?? sysctlString(named: "hw.model")
            ?? "Apple Silicon"
    }()

    func currentUsage() -> Double {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &infoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return 0
        }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: cpuInfo),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        let cpuStride = Int(CPU_STATE_MAX)
        let processors = Int(cpuCount)
        let samples = UnsafeBufferPointer(start: cpuInfo, count: Int(infoCount))

        var totalTicks: [Int32] = []
        var idleTicks: [Int32] = []
        totalTicks.reserveCapacity(processors)
        idleTicks.reserveCapacity(processors)

        for processor in 0..<processors {
            let base = processor * cpuStride
            let user = samples[base + Int(CPU_STATE_USER)]
            let system = samples[base + Int(CPU_STATE_SYSTEM)]
            let idle = samples[base + Int(CPU_STATE_IDLE)]
            let nice = samples[base + Int(CPU_STATE_NICE)]

            totalTicks.append(user + system + idle + nice)
            idleTicks.append(idle)
        }

        defer {
            previousTotalTicks = totalTicks
            previousIdleTicks = idleTicks
        }

        guard
            let previousTotalTicks,
            let previousIdleTicks,
            previousTotalTicks.count == totalTicks.count,
            previousIdleTicks.count == idleTicks.count
        else {
            return 0.0
        }

        var totalDelta: Int64 = 0
        var idleDelta: Int64 = 0

        for index in totalTicks.indices {
            totalDelta += Int64(totalTicks[index] - previousTotalTicks[index])
            idleDelta += Int64(idleTicks[index] - previousIdleTicks[index])
        }

        guard totalDelta > 0 else { return 0 }
        let usage = Double(totalDelta - idleDelta) / Double(totalDelta) * 100.0
        return max(0, min(usage, 100))
    }

    func modelName() -> String {
        cachedModelName
    }

    func topProcesses(limit: Int = 5) -> [ProcessMetric] {
        let result = processRunner.runShell("ps -axo pid,%cpu,comm -r | head -n \(limit + 1)")
        guard result.terminationStatus == 0 else { return [] }

        var processes: [ProcessMetric] = []
        let lines = result.stdout.components(separatedBy: "\n").dropFirst()  // Skip header

        for (index, line) in lines.prefix(limit).enumerated() {
            let components = line
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard components.count >= 3,
                  let pid = Int32(components[0]),
                  let cpu = Double(components[1]) else { continue }

            let name = (components.dropFirst(2).joined(separator: " ") as NSString).lastPathComponent
            processes.append(ProcessMetric(name: name, pid: pid, value: cpu, ranking: index + 1))
        }

        return processes
    }

    private func sysctlString(named name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else {
            return nil
        }

        var value = [CChar](repeating: 0, count: Int(size))
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            return nil
        }

        let string = String(cString: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? nil : string
    }
}
