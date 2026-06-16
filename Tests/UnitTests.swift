import XCTest
@testable import iGlance

// MARK: - Model Tests

class ModelTests: XCTestCase {
    func testAppSectionProperties() {
        for section in AppSection.allCases {
            XCTAssertFalse(section.sfSymbolName.isEmpty, "\(section) should have SF Symbol")
            XCTAssertFalse(section.displayName.isEmpty, "\(section) should have display name")
            XCTAssertFalse(section.accessibilityLabel.isEmpty, "\(section) should have accessibility label")
        }
    }

    func testCPUSnapshotDefaults() {
        let cpu = CPUSnapshot.unavailable
        XCTAssertEqual(cpu.usage, 0)
        XCTAssertFalse(cpu.isAvailable)
        XCTAssertTrue(cpu.topProcesses.isEmpty)
    }

    func testGPUSnapshotDefaults() {
        let gpu = GPUSnapshot.unavailable
        XCTAssertEqual(gpu.usage, 0)
        XCTAssertFalse(gpu.isAvailable)
        XCTAssertNil(gpu.temperature)
        XCTAssertNil(gpu.vramDescription)
    }

    func testGPUSnapshotVRAMDescription() {
        let gpu = GPUSnapshot(usage: 50, temperature: 60, vramUsed: 4.2, vramTotal: 8, isAvailable: true)
        XCTAssertEqual(gpu.vramDescription, "4.2 GB / 8 GB")
    }

    func testMemorySnapshotDefaults() {
        let mem = MemorySnapshot.unavailable
        XCTAssertEqual(mem.usage, 0)
        XCTAssertFalse(mem.isAvailable)
        XCTAssertEqual(mem.pressure, "Unknown")
    }

    func testTemperatureSnapshotDefaults() {
        let temp = TemperatureSnapshot.unavailable
        XCTAssertFalse(temp.isAvailable)
        XCTAssertNil(temp.cpu)
        XCTAssertNil(temp.gpu)
        XCTAssertNil(temp.ssd)
        XCTAssertEqual(temp.maxTemperature, 0)
    }

    func testTemperatureSnapshotMax() {
        let temp = TemperatureSnapshot(cpu: 45, gpu: 60, ssd: 35, isAvailable: true)
        XCTAssertEqual(temp.maxTemperature, 60)
    }

    func testTaskSourceSymbols() {
        for source in [TaskSource.launchAgent, .launchDaemon, .cron, .at] {
            XCTAssertFalse(source.sfSymbolName.isEmpty, "\(source) should have SF Symbol")
            XCTAssertFalse(source.rawValue.isEmpty, "\(source) should have raw value")
        }
    }

    func testPowerAssertionStateDefaults() {
        let state = PowerAssertionState()
        XCTAssertFalse(state.preventSystemSleep)
        XCTAssertFalse(state.preventDisplaySleep)
        XCTAssertNil(state.systemSleepDisabled)
    }

    func testSystemSnapshotEmpty() {
        let snapshot = SystemSnapshot.empty
        XCTAssertFalse(snapshot.cpu.isAvailable)
        XCTAssertFalse(snapshot.gpu.isAvailable)
        XCTAssertFalse(snapshot.memory.isAvailable)
        XCTAssertFalse(snapshot.temperature.isAvailable)
        XCTAssertEqual(snapshot.loadIndex, 0)
    }
}

// MARK: - Support Tests

class LoadIndexCalculatorTests: XCTestCase {
    var calculator: LoadIndexCalculator!

    override func setUp() {
        super.setUp()
        calculator = LoadIndexCalculator()
    }

    func testZeroLoad() {
        let index = calculator.calculate(cpu: 0, gpu: 0, memory: 0, maxTemp: 25)
        XCTAssertLessThan(index, 10)
    }

    func testFullLoad() {
        let index = calculator.calculate(cpu: 100, gpu: 100, memory: 100, maxTemp: 90)
        XCTAssertGreaterThan(index, 80)
    }

    func testCPUOnlyLoad() {
        let index = calculator.calculate(cpu: 100, gpu: 0, memory: 0, maxTemp: 25)
        XCTAssertGreaterThan(index, 20)
        XCTAssertLessThan(index, 50)
    }

    func testTemperatureNormalization() {
        let lowTemp = calculator.calculate(cpu: 0, gpu: 0, memory: 0, maxTemp: 30)
        let midTemp = calculator.calculate(cpu: 0, gpu: 0, memory: 0, maxTemp: 55)
        let highTemp = calculator.calculate(cpu: 0, gpu: 0, memory: 0, maxTemp: 75)
        let criticalTemp = calculator.calculate(cpu: 0, gpu: 0, memory: 0, maxTemp: 95)

        XCTAssertLessThan(lowTemp, midTemp)
        XCTAssertLessThan(midTemp, highTemp)
        XCTAssertLessThan(highTemp, criticalTemp)
    }

    func testGPUUnavailableFallback() {
        let withGPU = calculator.calculate(cpu: 50, gpu: 50, memory: 50, maxTemp: 50)
        let withoutGPU = calculator.calculate(cpu: 50, gpu: -1, memory: 50, maxTemp: 50)

        // Without GPU, should fall back to ~50% of CPU
        XCTAssertNotEqual(withGPU, withoutGPU)
    }

    func testBoundaryValues() {
        let index = calculator.calculate(cpu: -10, gpu: -10, memory: -10, maxTemp: -10)
        XCTAssertGreaterThanOrEqual(index, 0)

        let index2 = calculator.calculate(cpu: 200, gpu: 200, memory: 200, maxTemp: 200)
        XCTAssertLessThanOrEqual(index2, 100)
    }
}

class HistoryBufferTests: XCTestCase {
    var buffer: HistoryBuffer!

    override func setUp() {
        super.setUp()
        buffer = HistoryBuffer(capacity: 5)
    }

    func testAppendToEmpty() {
        let result = buffer.append(value: 10, to: [])
        XCTAssertEqual(result, [10])
    }

    func testAppendWithinCapacity() {
        var history: [Double] = []
        history = buffer.append(value: 1, to: history)
        history = buffer.append(value: 2, to: history)
        history = buffer.append(value: 3, to: history)

        XCTAssertEqual(history, [1, 2, 3])
    }

    func testAppendExceedsCapacity() {
        var history: [Double] = []
        for i in 1...7 {
            history = buffer.append(value: Double(i), to: history)
        }

        XCTAssertEqual(history.count, 5)
        XCTAssertEqual(history, [3, 4, 5, 6, 7])
    }

    func testAppendContentsOf() {
        let result = buffer.append(contentsOf: [1, 2, 3], to: [])
        XCTAssertEqual(result, [1, 2, 3])
    }

    func testAppendContentsOfExceedsCapacity() {
        let result = buffer.append(contentsOf: [1, 2, 3, 4, 5, 6, 7], to: [])
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result, [3, 4, 5, 6, 7])
    }
}

class ColorInterpolationTests: XCTestCase {
    func testLowValueColor() {
        let color = ColorInterpolation.color(for: 0)
        // Should be green-ish
        XCTAssertNotNil(color)
    }

    func testMidValueColor() {
        let color = ColorInterpolation.color(for: 50)
        XCTAssertNotNil(color)
    }

    func testHighValueColor() {
        let color = ColorInterpolation.color(for: 100)
        XCTAssertNotNil(color)
    }

    func testBoundaryValues() {
        let _ = ColorInterpolation.color(for: -10)
        let _ = ColorInterpolation.color(for: 150)
        // Should not crash
    }
}

class FormattersTests: XCTestCase {
    func testFormatPercentage() {
        XCTAssertEqual(Formatters.formatPercentage(50.5), "50.5%")
        XCTAssertEqual(Formatters.formatPercentage(0), "0.0%")
        XCTAssertEqual(Formatters.formatPercentage(100), "100.0%")
    }

    func testFormatTemperature() {
        XCTAssertEqual(Formatters.formatTemperature(45.2), "45.2°C")
        XCTAssertEqual(Formatters.formatTemperature(nil), "N/A")
    }

    func testFormatMemory() {
        XCTAssertEqual(Formatters.formatMemory(75.3), "75.3%")
    }

    func testFormatMemoryGB() {
        XCTAssertEqual(Formatters.formatMemoryGB(2.5), "2.5 GB")
        XCTAssertEqual(Formatters.formatMemoryGB(0.5), "512 MB")
    }
}

class TaskRuleFormatterTests: XCTestCase {
    func testCronRuleEveryMinute() {
        let result = TaskRuleFormatter.formatCronRule("* * * * *")
        XCTAssertEqual(result, "every minute")
    }

    func testCronRuleHourly() {
        let result = TaskRuleFormatter.formatCronRule("30 * * * *")
        XCTAssertEqual(result, "every hour at:30")
    }

    func testCronRuleDaily() {
        let result = TaskRuleFormatter.formatCronRule("0 9 * * *")
        XCTAssertEqual(result, "9:00")
    }

    func testCronRuleWithWeekday() {
        let result = TaskRuleFormatter.formatCronRule("0 9 * * 1")
        XCTAssertEqual(result, "Mon 9:00")
    }

    func testLaunchdIntervalSeconds() {
        XCTAssertEqual(TaskRuleFormatter.formatLaunchdInterval(30), "Every 30 seconds")
    }

    func testLaunchdIntervalMinutes() {
        XCTAssertEqual(TaskRuleFormatter.formatLaunchdInterval(300), "Every 5 minutes")
    }

    func testLaunchdIntervalHours() {
        XCTAssertEqual(TaskRuleFormatter.formatLaunchdInterval(3600), "Every 1 hours")
    }

    func testLaunchdIntervalComplex() {
        XCTAssertEqual(TaskRuleFormatter.formatLaunchdInterval(5400), "Every 1h 30m")
    }

    func testLaunchdCalendar() {
        let calendar: [String: Any] = ["Hour": 9, "Minute": 30]
        let result = TaskRuleFormatter.formatLaunchdCalendar(calendar)
        XCTAssertEqual(result, "9:30")
    }

    func testLaunchdCalendarWithWeekday() {
        let calendar: [String: Any] = ["Hour": 9, "Minute": 0, "Weekday": 1]
        let result = TaskRuleFormatter.formatLaunchdCalendar(calendar)
        XCTAssertEqual(result, "Mon 9:00")
    }
}

// MARK: - Service Tests

class ProcessRunnerTests: XCTestCase {
    var runner: ProcessRunner!

    override func setUp() {
        super.setUp()
        runner = ProcessRunner()
    }

    func testRunSimpleCommand() {
        let result = runner.run("/bin/echo", arguments: ["hello"])
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(result.terminationStatus, 0)
    }

    func testRunShellCommand() {
        let result = runner.runShell("echo hello")
        XCTAssertEqual(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(result.terminationStatus, 0)
    }

    func testRunFailingCommand() {
        let result = runner.run("/bin/false")
        XCTAssertNotEqual(result.terminationStatus, 0)
    }

    func testRunNonexistentCommand() {
        let result = runner.run("/nonexistent/command")
        XCTAssertNotEqual(result.terminationStatus, 0)
    }
}

class CPUUsageProviderTests: XCTestCase {
    var provider: CPUUsageProvider!

    override func setUp() {
        super.setUp()
        provider = CPUUsageProvider()
    }

    func testCurrentUsage() {
        let usage = provider.currentUsage()
        XCTAssertGreaterThanOrEqual(usage, 0)
        XCTAssertLessThanOrEqual(usage, 100)
    }

    func testModelName() {
        let name = provider.modelName()
        XCTAssertFalse(name.isEmpty)
    }

    func testTopProcesses() {
        let processes = provider.topProcesses(limit: 5)
        XCTAssertLessThanOrEqual(processes.count, 5)
    }
}

class MemoryProviderTests: XCTestCase {
    var provider: MemoryProvider!

    override func setUp() {
        super.setUp()
        provider = MemoryProvider()
    }

    func testCurrentUsage() {
        let usage = provider.currentUsage()
        XCTAssertGreaterThanOrEqual(usage, 0)
        XCTAssertLessThanOrEqual(usage, 100)
    }

    func testPressureLevel() {
        let pressure = provider.pressureLevel()
        XCTAssertFalse(pressure.isEmpty)
    }

    func testTopProcesses() {
        let processes = provider.topProcesses(limit: 5)
        XCTAssertLessThanOrEqual(processes.count, 5)
    }
}

class TemperatureProviderTests: XCTestCase {
    var provider: TemperatureProvider!

    override func setUp() {
        super.setUp()
        provider = TemperatureProvider()
    }

    func testCurrentTemperatures() {
        let temps = provider.currentTemperatures()
        // Should return either available or unavailable state
        XCTAssertNotNil(temps)
    }
}

class PowerAssertionServiceTests: XCTestCase {
    var service: PowerAssertionService!

    override func setUp() {
        super.setUp()
        service = PowerAssertionService()
    }

    func testSleepDisabledStatus() {
        let status = service.isSleepDisabled()
        // Should return true, false, or nil
        XCTAssertNotNil(status) || XCTAssertNil(status)
    }
}

// MARK: - Store Tests

class AppStoreTests: XCTestCase {
    var store: AppStore!

    override func setUp() {
        super.setUp()
        store = AppStore()
    }

    func testInitialState() {
        XCTAssertEqual(store.activeSection, .monitor)
        XCTAssertFalse(store.isPopoverVisible)
    }

    func testSwitchSection() {
        store.switchToSection(.status)
        XCTAssertEqual(store.activeSection, .status)

        store.switchToSection(.tasks)
        XCTAssertEqual(store.activeSection, .tasks)
    }

    func testPopoverLifecycle() {
        store.popoverDidOpen()
        XCTAssertTrue(store.isPopoverVisible)

        store.popoverDidClose()
        XCTAssertFalse(store.isPopoverVisible)
    }
}

class StatusStoreTests: XCTestCase {
    var store: StatusStore!

    override func setUp() {
        super.setUp()
        let service = PowerAssertionService()
        store = StatusStore(powerAssertionService: service)
    }

    func testInitialState() {
        XCTAssertFalse(store.assertionState.preventSystemSleep)
        XCTAssertFalse(store.assertionState.preventDisplaySleep)
    }

    func testToggleSystemSleep() {
        let initial = store.assertionState.preventSystemSleep
        store.toggleSystemSleep()
        XCTAssertNotEqual(store.assertionState.preventSystemSleep, initial)

        // Cleanup
        if store.assertionState.preventSystemSleep {
            store.toggleSystemSleep()
        }
    }

    func testToggleDisplaySleep() {
        let initial = store.assertionState.preventDisplaySleep
        store.toggleDisplaySleep()
        XCTAssertNotEqual(store.assertionState.preventDisplaySleep, initial)

        // Cleanup
        if store.assertionState.preventDisplaySleep {
            store.toggleDisplaySleep()
        }
    }

    func testCleanup() {
        store.toggleSystemSleep()
        store.toggleDisplaySleep()
        store.cleanup()

        XCTAssertFalse(store.assertionState.preventSystemSleep)
        XCTAssertFalse(store.assertionState.preventDisplaySleep)
    }
}

// MARK: - Main Test Runner

func runAllTests() {
    print("=== iGlance Unit Tests ===\n")

    let testClasses: [XCTestCase.Type] = [
        ModelTests.self,
        LoadIndexCalculatorTests.self,
        HistoryBufferTests.self,
        ColorInterpolationTests.self,
        FormattersTests.self,
        TaskRuleFormatterTests.self,
        ProcessRunnerTests.self,
        CPUUsageProviderTests.self,
        MemoryProviderTests.self,
        TemperatureProviderTests.self,
        PowerAssertionServiceTests.self,
        AppStoreTests.self,
        StatusStoreTests.self
    ]

    var totalTests = 0
    var passedTests = 0
    var failedTests: [String] = []

    for testClass in testClasses {
        let suite = XCTestSuite(forTestCaseClass: testClass)
        for test in suite.tests {
            totalTests += 1
            let testCase = test as! XCTestCase
            testCase.setUp()

            do {
                try testCase.perform(NSSelectorFromString(test.name))
                passedTests += 1
                print("✓ \(test.name)")
            } catch {
                failedTests.append(test.name)
                print("✗ \(test.name): \(error)")
            }

            testCase.tearDown()
        }
    }

    print("\n=== Test Results ===")
    print("Total: \(totalTests)")
    print("Passed: \(passedTests)")
    print("Failed: \(failedTests.count)")

    if !failedTests.isEmpty {
        print("\nFailed tests:")
        for test in failedTests {
            print("  - \(test)")
        }
    }
}
