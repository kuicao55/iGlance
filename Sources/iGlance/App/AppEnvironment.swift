import Foundation

/// Dependency container for the application
class AppEnvironment {
    // Stores
    let appStore: AppStore
    let monitorStore: MonitorStore
    let statusStore: StatusStore
    let servicesStore: ServicesStore
    let updateStore: UpdateStore

    // Services (system data providers)
    let cpuProvider: CPUUsageProvider
    let gpuProvider: GPUUsageProvider
    let memoryProvider: MemoryProvider
    let diskProvider: DiskUsageProvider
    let systemInfoProvider: SystemInfoProvider
    let temperatureProvider: TemperatureProvider
    let powerAssertionService: PowerAssertionService

    // Support
    let loadIndexCalculator: LoadIndexCalculator
    let iconRenderer: MenuBarIconRenderer
    let iconAnimator: MenuBarIconAnimator

    init() {
        // Initialize providers
        self.cpuProvider = CPUUsageProvider()
        self.gpuProvider = GPUUsageProvider()
        self.memoryProvider = MemoryProvider()
        self.diskProvider = DiskUsageProvider()
        self.systemInfoProvider = SystemInfoProvider()
        self.temperatureProvider = TemperatureProvider()
        self.powerAssertionService = PowerAssertionService()

        // Initialize support
        self.loadIndexCalculator = LoadIndexCalculator()
        self.iconRenderer = MenuBarIconRenderer()
        self.iconAnimator = MenuBarIconAnimator()

        // Initialize stores
        self.appStore = AppStore()
        self.monitorStore = MonitorStore(
            cpuProvider: cpuProvider,
            gpuProvider: gpuProvider,
            memoryProvider: memoryProvider,
            diskProvider: diskProvider,
            systemInfoProvider: systemInfoProvider,
            temperatureProvider: temperatureProvider,
            loadIndexCalculator: loadIndexCalculator
        )
        self.statusStore = StatusStore(powerAssertionService: powerAssertionService)
        self.servicesStore = ServicesStore()
        self.updateStore = UpdateStore()
    }
}
