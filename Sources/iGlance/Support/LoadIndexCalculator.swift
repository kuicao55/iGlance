import Foundation

class LoadIndexCalculator {
    func calculate(cpu: Double, gpu: Double, memory: Double, maxTemp: Double) -> Double {
        let normalizedCPU = min(max(cpu, 0), 100)
        let normalizedMemory = min(max(memory, 0), 100)
        return max(normalizedCPU, normalizedMemory)
    }
}
