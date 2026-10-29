import Foundation
import Combine

class MonitorStore: ObservableObject {
    @Published var currentSnapshot: SystemSnapshot = .empty
    @Published var loadIndex: Double = 0
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var isCPUCardFlipped = false
    @Published var isMemoryCardFlipped = false

    private let cpuProvider: CPUUsageProvider
    private let memoryProvider: MemoryProvider
    private let diskProvider: DiskUsageProvider
    private let systemInfoProvider: SystemInfoProvider
    private let temperatureProvider: TemperatureProvider
    private let loadIndexCalculator: LoadIndexCalculator
    private let cpuModelName: String
    private let totalMemoryGB: Double

    private var detailedRefreshTimer: Timer?
    private let historyBuffer = HistoryBuffer(capacity: 30)  // 60 seconds at 2s intervals
    private let refreshQueue = DispatchQueue(label: "com.iglance.monitor.refresh", qos: .userInitiated)

    // Temperature probing shells out, so sample it every third tick (~6s)
    // while the popover is open and reuse the last snapshot in between.
    private var detailedTick = 0
    private var cachedTemperatures = TemperatureSnapshot.unavailable

    init(
        cpuProvider: CPUUsageProvider,
        gpuProvider: GPUUsageProvider,
        memoryProvider: MemoryProvider,
        diskProvider: DiskUsageProvider,
        systemInfoProvider: SystemInfoProvider,
        temperatureProvider: TemperatureProvider,
        loadIndexCalculator: LoadIndexCalculator
    ) {
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.diskProvider = diskProvider
        self.systemInfoProvider = systemInfoProvider
        self.temperatureProvider = temperatureProvider
        self.loadIndexCalculator = loadIndexCalculator
        self.cpuModelName = cpuProvider.modelName()
        self.totalMemoryGB = systemInfoProvider.totalMemoryGB()
    }

    /// Called by StatusItemController every 2 seconds (lightweight, for icon only)
    func refreshMenuBarMetrics() {
        // Detailed refresh already recomputes the load index while the
        // popover is open; skip the duplicate sampling.
        guard detailedRefreshTimer == nil else { return }

        refreshQueue.async { [weak self] in
            guard let self = self else { return }

            let cpu = self.cpuProvider.currentUsage()
            let memory = self.memoryProvider.currentUsage()
            let index = self.loadIndexCalculator.calculate(cpu: cpu, gpu: 0, memory: memory, maxTemp: 0)

            DispatchQueue.main.async {
                self.loadIndex = index
            }
        }
    }

    /// Start detailed refresh when popover opens
    func startDetailedRefresh() {
        stopDetailedRefresh()

        detailedRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshDetailedSnapshot()
        }
        // Immediate refresh
        refreshDetailedSnapshot()
    }

    /// Stop detailed refresh when popover closes
    func stopDetailedRefresh() {
        detailedRefreshTimer?.invalidate()
        detailedRefreshTimer = nil
    }

    private func refreshDetailedSnapshot() {
        let samplesTemperature = detailedTick % 3 == 0
        detailedTick += 1
        let cached = cachedTemperatures

        refreshQueue.async { [weak self] in
            guard let self = self else { return }

            let cpuUsage = self.cpuProvider.currentUsage()
            let topCPUProcesses = self.cpuProvider.topProcesses(limit: 5)

            let memoryUsage = self.memoryProvider.currentUsage()
            let memoryPressure = self.memoryProvider.pressureLevel()
            let topMemoryProcesses = self.memoryProvider.topProcesses(limit: 5)
            let disk = self.diskProvider.currentUsage()

            let temps = samplesTemperature ? self.temperatureProvider.currentTemperatures() : cached

            let cpu = CPUSnapshot(usage: cpuUsage, modelName: self.cpuModelName, topProcesses: topCPUProcesses, isAvailable: true)
            let gpu = GPUSnapshot(
                usage: 0,
                temperature: nil,
                vramUsed: nil,
                vramTotal: nil,
                modelName: nil,
                coreCount: nil,
                isAvailable: false
            )
            let memory = MemorySnapshot(
                usage: memoryUsage,
                usedMemoryGB: self.memoryProvider.usedMemoryGB(),
                totalMemoryGB: self.totalMemoryGB > 0 ? self.totalMemoryGB : nil,
                pressure: memoryPressure,
                topProcesses: topMemoryProcesses,
                isAvailable: true
            )

            let index = self.loadIndexCalculator.calculate(cpu: cpuUsage, gpu: 0, memory: memoryUsage, maxTemp: 0)

            DispatchQueue.main.async {
                if samplesTemperature {
                    self.cachedTemperatures = temps
                }

                self.currentSnapshot = SystemSnapshot(
                    timestamp: Date(),
                    cpu: cpu,
                    gpu: gpu,
                    memory: memory,
                    disk: disk,
                    temperature: temps,
                    loadIndex: index
                )
                self.loadIndex = index

                self.cpuHistory = self.historyBuffer.append(value: cpuUsage, to: self.cpuHistory)
                self.memoryHistory = self.historyBuffer.append(value: memoryUsage, to: self.memoryHistory)
            }
        }
    }
}
