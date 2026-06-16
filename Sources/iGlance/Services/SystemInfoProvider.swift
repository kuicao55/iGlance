import Foundation
import Darwin

class SystemInfoProvider {
    private lazy var cachedCPUModelName: String = {
        sysctlString(named: "machdep.cpu.brand_string")
            ?? sysctlString(named: "hw.model")
            ?? "Apple Silicon"
    }()

    private lazy var cachedTotalMemoryGB: Double = {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
    }()

    func cpuModelName() -> String {
        cachedCPUModelName
    }

    func totalMemoryGB() -> Double {
        cachedTotalMemoryGB
    }

    func osVersion() -> String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    func hostname() -> String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
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
