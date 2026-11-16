import XCTest
import Foundation
import Darwin
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

    func testSettingsIsAFullSection() {
        XCTAssertTrue(AppSection.allCases.contains(.settings))
        XCTAssertEqual(AppSection.settings.displayName, "Settings")
        XCTAssertFalse(AppSection.settings.sfSymbolName.isEmpty)
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
        let gpu = GPUSnapshot(usage: 50, temperature: 60, vramUsed: 4.2, vramTotal: 8, modelName: nil, coreCount: nil, isAvailable: true)
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
        XCTAssertNil(temp.battery)
        XCTAssertEqual(temp.maxTemperature, 0)
    }

    func testTemperatureSnapshotMax() {
        let temp = TemperatureSnapshot(cpu: 45, gpu: 60, battery: 35, isAvailable: true)
        XCTAssertEqual(temp.maxTemperature, 60)
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
        // The current index is max(cpu, memory); GPU and temperature are not
        // part of it yet.
        let index = calculator.calculate(cpu: 100, gpu: 0, memory: 0, maxTemp: 25)
        XCTAssertEqual(index, 100)
    }

    func testMemoryDominates() {
        let index = calculator.calculate(cpu: 10, gpu: 0, memory: 80, maxTemp: 25)
        XCTAssertEqual(index, 80)
    }

    func testTemperatureNormalization() {
        let lowTemp = calculator.calculate(cpu: 50, gpu: 0, memory: 50, maxTemp: 30)
        let criticalTemp = calculator.calculate(cpu: 50, gpu: 0, memory: 50, maxTemp: 95)
        XCTAssertEqual(lowTemp, criticalTemp)
    }

    func testGPUUnavailableFallback() {
        let withGPU = calculator.calculate(cpu: 50, gpu: 50, memory: 50, maxTemp: 50)
        let withoutGPU = calculator.calculate(cpu: 50, gpu: -1, memory: 50, maxTemp: 50)
        XCTAssertEqual(withGPU, withoutGPU)
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

    func testLaunchDetachedReportsImmediateFailure() {
        let result = runner.launchDetachedShell("exit 7", grace: 2)
        XCTAssertEqual(result.terminationStatus, 7)
    }

    func testLaunchDetachedLeavesRunningCommandAlone() {
        let result = runner.launchDetachedShell("sleep 1", grace: 0.2)
        XCTAssertEqual(result.terminationStatus, 0)
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
        // Should return true, false, or nil without crashing.
        _ = service.isSleepDisabled()
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

        store.switchToSection(.services)
        XCTAssertEqual(store.activeSection, .services)
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


// MARK: - Services

class ServiceManifestParserTests: XCTestCase {
    private let manifestJSON = """
    {"schema":"iglance.service.v1","service":{"id":"gofer","name":"Gofer","version":"0.4.0","kind":"headless-service"},"base_url":"http://127.0.0.1:8790","auth":{"type":"header","header":"X-Gofer-Token"},"endpoints":{"health":"/health","status":"/api/v1/service","memory":"/api/v1/service/memory","pause":"/api/v1/service/pause","resume":"/api/v1/service/resume","toggle":"/api/v1/service/toggle","stop":"/api/v1/service/stop"}}
    """

    private var manifestLine: String {
        "\(ServiceManifestParser.prefix) \(manifestJSON)"
    }

    func testParsesManifestLine() throws {
        let manifest = try ServiceManifestParser.parse(line: manifestLine)
        XCTAssertEqual(manifest.schema, "iglance.service.v1")
        XCTAssertEqual(manifest.service.id, "gofer")
        XCTAssertEqual(manifest.service.name, "Gofer")
        XCTAssertEqual(manifest.service.version, "0.4.0")
        XCTAssertEqual(manifest.baseURL.absoluteString, "http://127.0.0.1:8790")
        XCTAssertEqual(manifest.auth?.header, "X-Gofer-Token")
        XCTAssertEqual(manifest.endpoints["status"], "/api/v1/service")
        XCTAssertEqual(manifest.endpoints.count, 7)
    }

    func testFindsManifestAmongOrdinaryLogs() throws {
        let output = """
        starting gofer...
        loaded plugins
        \(manifestLine)
        still running
        """
        let manifest = ServiceManifestParser.manifest(in: output)
        XCTAssertEqual(manifest?.service.id, "gofer")
    }

    func testTrimsTrailingSlashFromBaseURL() throws {
        let json = manifestJSON.replacingOccurrences(of: "\"base_url\":\"http://127.0.0.1:8790\"", with: "\"base_url\":\"http://127.0.0.1:8790/\"")
        let manifest = try ServiceManifestParser.parse(line: "\(ServiceManifestParser.prefix) \(json)")
        XCTAssertEqual(manifest.baseURL.absoluteString, "http://127.0.0.1:8790")
    }

    func testRejectsWrongSchema() {
        let json = manifestJSON.replacingOccurrences(of: "iglance.service.v1", with: "other.schema.v9")
        XCTAssertThrowsError(try ServiceManifestParser.parse(line: "\(ServiceManifestParser.prefix) \(json)")) { error in
            guard case ServiceManifestError.unsupportedSchema = error else {
                return XCTFail("Expected unsupportedSchema, got \(error)")
            }
        }
    }

    func testRejectsInvalidJSON() {
        XCTAssertThrowsError(try ServiceManifestParser.parse(line: "\(ServiceManifestParser.prefix) {nope")) { error in
            guard case ServiceManifestError.invalidJSON = error else {
                return XCTFail("Expected invalidJSON, got \(error)")
            }
        }
    }

    func testRejectsMissingPrefix() {
        XCTAssertThrowsError(try ServiceManifestParser.parse(line: "hello")) { error in
            guard case ServiceManifestError.missingPrefix = error else {
                return XCTFail("Expected missingPrefix, got \(error)")
            }
        }
    }

    func testRejectsInvalidBaseURL() {
        let json = manifestJSON.replacingOccurrences(of: "http://127.0.0.1:8790", with: "not-a-url")
        XCTAssertThrowsError(try ServiceManifestParser.parse(line: "\(ServiceManifestParser.prefix) \(json)"))
    }

    func testLoopbackDetection() {
        XCTAssertTrue(ServiceManifestParser.isLoopback(URL(string: "http://127.0.0.1:8790")!))
        XCTAssertTrue(ServiceManifestParser.isLoopback(URL(string: "http://localhost:8790")!))
        XCTAssertFalse(ServiceManifestParser.isLoopback(URL(string: "http://192.168.1.4:8790")!))
    }

    func testLineAccumulatorHandlesSplitChunks() {
        var accumulator = ServiceLineAccumulator()
        XCTAssertEqual(accumulator.append(Data("first line\nsec".utf8)), ["first line"])
        XCTAssertEqual(accumulator.append(Data("ond line\r\nthird".utf8)), ["second line"])
        XCTAssertEqual(accumulator.flush(), "third")
        XCTAssertNil(accumulator.flush())
    }
}

class ServiceMemoryParsingTests: XCTestCase {
    func testParsesGroupsAndTotals() throws {
        let json = """
        {"available":true,"source":"ps-rss","observed_at":"2026-10-28T21:42:45+08:00","total_rss_bytes":435896320,"total_processes":13,"groups":[{"id":"service","label":"Gofer","rss_bytes":12603392,"processes":1,"pids":[12345]},{"id":"wechat","label":"微信","rss_bytes":423292928,"processes":12,"pids":[12346]}]}
        """
        let memory = try ServiceJSON.decoder.decode(ServiceMemory.self, from: Data(json.utf8))
        XCTAssertTrue(memory.available)
        XCTAssertEqual(memory.source, "ps-rss")
        XCTAssertNotNil(memory.observedAt)
        XCTAssertEqual(memory.totalRssBytes, 435_896_320)
        XCTAssertEqual(memory.totalProcesses, 13)
        XCTAssertEqual(memory.groups.count, 2)
        XCTAssertEqual(memory.groups.first?.label, "Gofer")
        XCTAssertEqual(memory.groups.last?.pids, [12346])
    }

    func testFallsBackToLegacyNamedGroups() throws {
        let json = """
        {"available":true,"gofer":{"rss_bytes":10,"processes":1,"pids":[1]},"wechat":{"rss_bytes":20,"processes":2,"pids":[2]}}
        """
        let memory = try ServiceJSON.decoder.decode(ServiceMemory.self, from: Data(json.utf8))
        XCTAssertEqual(memory.groups.count, 2)
        XCTAssertEqual(memory.groups.map(\.id), ["gofer", "wechat"])
        XCTAssertEqual(memory.totalRssBytes, 30)
        XCTAssertEqual(memory.totalProcesses, 3)
    }

    func testUnavailableMemoryRendersDash() throws {
        let json = #"{"available":false,"error":"ps failed"}"#
        let memory = try ServiceJSON.decoder.decode(ServiceMemory.self, from: Data(json.utf8))
        XCTAssertFalse(memory.available)
        XCTAssertNil(memory.totalRssBytes)
        XCTAssertTrue(memory.groups.isEmpty)
        XCTAssertEqual(memory.error, "ps failed")
        XCTAssertEqual(Formatters.formatByteCount(memory.totalRssBytes), "—")
    }
}

class ServiceStateTests: XCTestCase {
    private func state(_ json: String) throws -> ServiceState {
        let response = try ServiceJSON.decoder.decode(ServiceStatusResponse.self, from: Data(json.utf8))
        return ServiceState.from(response)
    }

    func testStateMapping() throws {
        XCTAssertEqual(try state(#"{"state":"running","pid":42}"#), .running)
        XCTAssertEqual(try state(#"{"state":"running","paused":true}"#), .paused)
        XCTAssertEqual(try state(#"{"state":"stopping","stopping":true}"#), .stopping)
        XCTAssertEqual(try state(#"{"state":"stopped"}"#), .offline)
        XCTAssertEqual(try state(#"{"state":"mystery","pid":7}"#), .running)
        XCTAssertEqual(try state("{}"), .unknown)
        XCTAssertEqual(ServiceState.from(nil), .offline)
    }
}

class ServicePanelTests: XCTestCase {
    private func makeBinding(
        endpoints: [String: String]?,
        baseURL: String? = "http://127.0.0.1:8790",
        kind: ServiceKind = .manifest,
        panelURL: String? = nil
    ) -> ServiceBinding {
        ServiceBinding(
            name: "Gofer",
            startCommand: "true",
            kind: kind,
            panelURL: panelURL,
            baseURL: baseURL.flatMap { URL(string: $0) },
            endpoints: endpoints
        )
    }

    private func status(_ json: String) throws -> ServiceStatusResponse {
        try ServiceJSON.decoder.decode(ServiceStatusResponse.self, from: Data(json.utf8))
    }

    func testPanelURLPrefersStatusAbsoluteURL() throws {
        let binding = makeBinding(endpoints: ["panel": "/"])
        let status = try status(
            #"{"state":"running","urls":{"base":"http://127.0.0.1:8790","display":"https://gofer.tailnet.ts.net","panel":"https://gofer.tailnet.ts.net/"}}"#
        )
        XCTAssertEqual(binding.panelURL(status: status)?.absoluteString, "https://gofer.tailnet.ts.net/")
    }

    func testPanelURLUsesDisplayAddress() throws {
        let binding = makeBinding(endpoints: ["panel": "/admin"])
        let status = try status(
            #"{"urls":{"base":"http://127.0.0.1:8790","display":"http://100.64.0.2:8790"}}"#
        )
        XCTAssertEqual(binding.panelURL(status: status)?.absoluteString, "http://100.64.0.2:8790/admin")
    }

    func testPanelURLResolvesManifestPath() {
        let binding = makeBinding(endpoints: ["panel": "/"])
        XCTAssertEqual(binding.panelURL(status: nil)?.absoluteString, "http://127.0.0.1:8790/")
    }

    func testPanelURLAddsLeadingSlash() {
        let binding = makeBinding(endpoints: ["panel": "ui"])
        XCTAssertEqual(binding.panelURL(status: nil)?.absoluteString, "http://127.0.0.1:8790/ui")
    }

    func testPanelURLRejectsNonHTTP() throws {
        let binding = makeBinding(endpoints: nil)
        let status = try status(#"{"urls":{"panel":"javascript:alert(1)"}}"#)
        XCTAssertNil(binding.panelURL(status: status))
    }

    func testNoPanelEndpointReturnsNil() {
        let binding = makeBinding(endpoints: ["status": "/api/v1/service"])
        XCTAssertNil(binding.panelURL(status: nil))
    }

    // MARK: - Explicit panelURL (issue #4)

    func testManifestStatusPanelBeatsStoredPanelURL() throws {
        let binding = makeBinding(endpoints: nil, panelURL: "http://127.0.0.1:9999/")
        let status = try status(#"{"urls":{"panel":"https://gofer.tailnet.ts.net/"}}"#)
        XCTAssertEqual(binding.panelURL(status: status)?.absoluteString, "https://gofer.tailnet.ts.net/")
    }

    func testManifestEndpointPathBeatsStoredPanelURL() {
        let binding = makeBinding(endpoints: ["panel": "/admin"], panelURL: "http://127.0.0.1:9999/fallback")
        XCTAssertEqual(binding.panelURL(status: nil)?.absoluteString, "http://127.0.0.1:8790/admin")
    }

    func testManifestStoredPanelURLIsFallback() {
        let binding = makeBinding(endpoints: nil, panelURL: "http://hermes.gateway/router")
        XCTAssertEqual(binding.panelURL(status: nil)?.absoluteString, "http://hermes.gateway/router")
    }

    func testNonManifestUsesStoredPanelURL() {
        for kind in [ServiceKind.launchd, .process, .command] {
            let binding = makeBinding(
                endpoints: nil,
                kind: kind,
                panelURL: "https://hermes.gateway/router"
            )
            XCTAssertEqual(
                binding.panelURL(status: nil)?.absoluteString,
                "https://hermes.gateway/router",
                "kind \(kind.rawValue)"
            )
        }
    }

    func testStoredPanelURLTrimsWhitespace() {
        let binding = makeBinding(endpoints: nil, kind: .process, panelURL: "  https://hermes.gateway/ui  ")
        XCTAssertEqual(binding.panelURL(status: nil)?.absoluteString, "https://hermes.gateway/ui")
    }

    func testStoredPanelURLRejectsNonHTTP() {
        let binding = makeBinding(endpoints: nil, kind: .launchd, panelURL: "file:///etc/passwd")
        XCTAssertNil(binding.panelURL(status: nil))
    }

    func testStoredPanelURLEmptyReturnsNil() {
        let binding = makeBinding(endpoints: nil, kind: .command, panelURL: "   ")
        XCTAssertNil(binding.panelURL(status: nil))
    }
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

class ServiceClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeClient() -> ServiceClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return ServiceClient(session: URLSession(configuration: configuration))
    }

    private func makeBinding() -> ServiceBinding {
        ServiceBinding(
            name: "Gofer",
            startCommand: "true",
            baseURL: URL(string: "http://127.0.0.1:8790")!,
            endpoints: ["status": "/api/v1/service", "memory": "/api/v1/service/memory"],
            auth: ServiceManifestAuth(type: "header", header: "X-Gofer-Token")
        )
    }

    func testUnauthorizedIsReported() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await makeClient().fetchStatus(binding: makeBinding(), token: "wrong")
            XCTFail("Expected an unauthorized error")
        } catch let error as ServiceClientError {
            XCTAssertTrue(error.isUnauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConnectionFailureIsReported() async {
        MockURLProtocol.handler = { _ in
            throw URLError(.cannotConnectToHost)
        }

        do {
            _ = try await makeClient().fetchStatus(binding: makeBinding(), token: nil)
            XCTFail("Expected a connection failure")
        } catch let error as ServiceClientError {
            XCTAssertTrue(error.isConnectionFailure)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDecodesStatusAndSendsAuthHeader() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Gofer-Token"), "secret")
            let json = """
            {"schema":"iglance.service.v1","ok":true,"state":"running","paused":false,"stopping":false,"pid":12345,"started_at":"2026-10-28T21:42:45+08:00","uptime_sec":3600,"memory":{"available":true,"total_rss_bytes":1024,"groups":[{"id":"service","label":"Gofer","rss_bytes":1024,"processes":1,"pids":[12345]}]}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let status = try await makeClient().fetchStatus(binding: makeBinding(), token: "secret")
        XCTAssertEqual(status.pid, 12_345)
        XCTAssertEqual(status.uptimeSec, 3600)
        XCTAssertNotNil(status.startedAt)
        XCTAssertEqual(status.memory?.groups.count, 1)
        XCTAssertEqual(ServiceState.from(status), .running)
    }

    func testServerErrorIncludesMessage() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data("boom".utf8))
        }

        do {
            _ = try await makeClient().fetchStatus(binding: makeBinding(), token: nil)
            XCTFail("Expected a server error")
        } catch let error as ServiceClientError {
            if case .server(let status, let message) = error {
                XCTAssertEqual(status, 500)
                XCTAssertTrue(message.contains("boom"))
            } else {
                XCTFail("Expected server error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAuthHeaderVariants() {
        XCTAssertEqual(
            ServiceClient.authHeaders(token: "abc", auth: ServiceManifestAuth(type: "header", header: "X-Gofer-Token")),
            ["X-Gofer-Token": "abc"]
        )
        XCTAssertEqual(
            ServiceClient.authHeaders(token: "abc", auth: ServiceManifestAuth(type: "header", header: "Authorization")),
            ["Authorization": "Bearer abc"]
        )
        XCTAssertEqual(
            ServiceClient.authHeaders(token: "abc", auth: ServiceManifestAuth(type: "none", header: "X-Gofer-Token")),
            [:]
        )
        XCTAssertEqual(ServiceClient.authHeaders(token: nil, auth: nil), [:])
        XCTAssertEqual(ServiceClient.authHeaders(token: "", auth: nil), [:])
    }

    func testBuildsURLWithQuery() {
        let url = ServiceClient.buildURL(
            baseURL: URL(string: "http://127.0.0.1:8790/")!,
            path: "/api/v1/service/stop",
            queryItems: [URLQueryItem(name: "cleanup", value: "true")]
        )
        XCTAssertEqual(url?.absoluteString, "http://127.0.0.1:8790/api/v1/service/stop?cleanup=true")
    }
}

class ServiceBindingStoreTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
    }

    func testSaveAndLoadRoundTrip() throws {
        let file = temporaryFile()
        let store = ServiceBindingStore(fileURL: file)
        let binding = ServiceBinding(
            name: "Gofer",
            startCommand: "~/Applications/Gofer/start-gofer.sh start --manifest",
            refreshSeconds: 5,
            baseURL: URL(string: "http://127.0.0.1:8790"),
            endpoints: ["status": "/api/v1/service"],
            auth: ServiceManifestAuth(type: "header", header: "X-Gofer-Token"),
            serviceID: "gofer",
            serviceVersion: "0.4.0",
            startCommandApproved: true
        )

        try store.save([binding])
        let loaded = store.load()
        XCTAssertEqual(loaded, [binding])
    }

    func testLoadMissingFileReturnsEmpty() {
        let store = ServiceBindingStore(fileURL: temporaryFile())
        XCTAssertTrue(store.load().isEmpty)
    }
}

class ServicesStoreTests: XCTestCase {
    private func makeStore(
        tokens: InMemoryServiceTokenStore = InMemoryServiceTokenStore(),
        bindingStore: ServiceBindingStore? = nil
    ) -> ServicesStore {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
        return ServicesStore(
            tokenStore: tokens,
            bindingStore: bindingStore ?? ServiceBindingStore(fileURL: file)
        )
    }

    func testAddAndDeleteBindingStoresToken() {
        let tokens = InMemoryServiceTokenStore()
        let store = makeStore(tokens: tokens)

        let binding = store.addService(
            name: "Gofer",
            startCommand: "echo hi",
            refreshSeconds: 5,
            token: "secret",
            startCommandApproved: true
        )

        XCTAssertNotNil(binding)
        XCTAssertEqual(store.bindings.count, 1)
        XCTAssertTrue(store.hasToken(for: binding!.id))
        XCTAssertEqual(tokens.token(for: binding!.id), "secret")

        store.deleteService(id: binding!.id)
        XCTAssertTrue(store.bindings.isEmpty)
        XCTAssertNil(tokens.token(for: binding!.id))
    }

    func testUnapprovedCommandDoesNotRun() {
        let store = makeStore()
        let binding = store.addService(
            name: "Gofer",
            startCommand: "echo hi",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: false
        )!

        store.start(bindingID: binding.id)

        XCTAssertEqual(store.runtime(for: binding.id).state, .offline)
        XCTAssertNotNil(store.lastActionError)
    }

    func testEditorKeepsDraftUntilItIsClosed() {
        let store = makeStore()

        store.beginAddingService()
        XCTAssertNotNil(store.editor)
        store.editor?.name = "Gofer"
        store.editor?.startCommand = "~/Applications/Gofer/start-gofer.sh start --manifest"

        // Nothing here closes the editor — like the popover closing and
        // reopening, the draft must still be there.
        XCTAssertEqual(store.editor?.name, "Gofer")
        XCTAssertFalse(store.editor?.isEditing ?? true)

        store.closeEditor()
        XCTAssertNil(store.editor)
    }

    func testEditingPrefillsFromBinding() {
        let store = makeStore()
        let binding = store.addService(
            name: "Gofer",
            startCommand: "gofer start --manifest",
            refreshSeconds: 9,
            token: nil,
            startCommandApproved: false
        )!

        store.beginEditingService(id: binding.id)

        XCTAssertEqual(store.editor?.editingID, binding.id)
        XCTAssertEqual(store.editor?.name, "Gofer")
        XCTAssertEqual(store.editor?.startCommand, "gofer start --manifest")
        XCTAssertEqual(store.editor?.refreshSeconds, 9)
        XCTAssertFalse(store.editor?.approved ?? true)
    }

    func testDeletingBindingClosesItsEditor() {
        let store = makeStore()
        let binding = store.addService(
            name: "Gofer",
            startCommand: "gofer start --manifest",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true
        )!

        store.beginEditingService(id: binding.id)
        store.deleteService(id: binding.id)

        XCTAssertNil(store.editor)
    }

    func testChangingCommandClearsDiscovery() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
        let binding = ServiceBinding(
            name: "Gofer",
            startCommand: "old --manifest",
            baseURL: URL(string: "http://127.0.0.1:8790"),
            endpoints: ["status": "/api/v1/service"],
            serviceID: "gofer",
            serviceVersion: "0.4.0",
            startCommandApproved: true
        )
        try ServiceBindingStore(fileURL: file).save([binding])

        let store = makeStore(bindingStore: ServiceBindingStore(fileURL: file))
        store.updateService(
            id: binding.id,
            name: "Gofer",
            startCommand: "new --manifest",
            refreshSeconds: 5,
            startCommandApproved: false,
            token: nil
        )

        let updated = store.binding(for: binding.id)
        XCTAssertNil(updated?.baseURL)
        XCTAssertNil(updated?.endpoints)
        XCTAssertNil(updated?.serviceID)
        XCTAssertFalse(updated?.startCommandApproved ?? true)
        XCTAssertEqual(store.runtime(for: binding.id).state, .offline)
    }
}

class ServiceFormattingTests: XCTestCase {
    func testByteCountUnavailableRendersDash() {
        XCTAssertEqual(Formatters.formatByteCount(nil), "—")
        XCTAssertEqual(Formatters.formatByteCount(-1), "—")
        XCTAssertFalse(Formatters.formatByteCount(0).isEmpty)
    }

    func testDurationFormatting() {
        XCTAssertEqual(Formatters.formatDuration(nil), "—")
        XCTAssertEqual(Formatters.formatDuration(5), "5s")
        XCTAssertEqual(Formatters.formatDuration(90), "1m 30s")
        XCTAssertEqual(Formatters.formatDuration(3_660), "1h 1m")
    }

    func testRelativeDateUnavailableRendersDash() {
        XCTAssertEqual(Formatters.formatRelativeDate(nil), "—")
    }
}


// MARK: - Service kinds

class ServiceKindMigrationTests: XCTestCase {
    private let legacyJSON = """
    [{
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Gofer",
      "startCommand": "gofer start --manifest",
      "refreshSeconds": 5,
      "baseURL": "http://127.0.0.1:8790",
      "endpoints": {"status": "/api/v1/service", "stop": "/api/v1/service/stop"},
      "serviceID": "gofer",
      "serviceVersion": "0.4.0",
      "startCommandApproved": true
    }]
    """

    func testDecodesLegacyBindingAsManifest() throws {
        let bindings = try JSONDecoder().decode([ServiceBinding].self, from: Data(legacyJSON.utf8))
        let binding = try XCTUnwrap(bindings.first)
        XCTAssertEqual(binding.kind, .manifest)
        XCTAssertFalse(binding.readOnly)
        XCTAssertEqual(binding.startCommand, "gofer start --manifest")
        XCTAssertEqual(binding.baseURL?.absoluteString, "http://127.0.0.1:8790")
        XCTAssertTrue(binding.isProbeable)
        XCTAssertTrue(binding.canStart)
        XCTAssertTrue(binding.canStop)
    }

    func testStoreLoadsLegacyFile() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try legacyJSON.write(to: file, atomically: true, encoding: .utf8)

        let loaded = ServiceBindingStore(fileURL: file).load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.kind, .manifest)
    }

    func testUnknownKindFallsBackToManifest() throws {
        let json = """
        [{
          "id": "33333333-3333-3333-3333-333333333333",
          "name": "Future",
          "startCommand": "future start",
          "kind": "container",
          "startCommandApproved": true
        }]
        """
        let binding = try XCTUnwrap(
            try JSONDecoder().decode([ServiceBinding].self, from: Data(json.utf8)).first
        )
        XCTAssertEqual(binding.kind, .manifest)
    }

    func testMissingApprovalDecodesAsUnapproved() throws {
        let json = """
        [{
          "id": "44444444-4444-4444-4444-444444444444",
          "name": "Legacy",
          "startCommand": "legacy start"
        }]
        """
        let binding = try XCTUnwrap(
            try JSONDecoder().decode([ServiceBinding].self, from: Data(json.utf8)).first
        )
        XCTAssertFalse(binding.startCommandApproved)
    }

    func testLaunchdWithoutReadOnlyDefaultsToReadOnly() throws {
        let json = """
        [{
          "id": "22222222-2222-2222-2222-222222222222",
          "name": "Hermes",
          "startCommand": "",
          "kind": "launchd",
          "launchdLabel": "ai.hermes.gateway",
          "startCommandApproved": true
        }]
        """
        let binding = try XCTUnwrap(
            try JSONDecoder().decode([ServiceBinding].self, from: Data(json.utf8)).first
        )
        XCTAssertEqual(binding.kind, .launchd)
        XCTAssertTrue(binding.readOnly)
        XCTAssertFalse(binding.canStart)
        XCTAssertFalse(binding.canStop)
        XCTAssertTrue(binding.isProbeable)
    }

    func testRoundTripsNewFields() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
        let binding = ServiceBinding(
            name: "Hermes",
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: false,
            statusCommand: "hermes gateway status",
            stopCommand: "hermes gateway stop",
            panelURL: "https://hermes.gateway/router",
            startCommandApproved: true
        )

        let store = ServiceBindingStore(fileURL: file)
        try store.save([binding])
        XCTAssertEqual(store.load(), [binding])
    }

    func testLegacyJSONDefaultsPanelURLToNil() throws {
        let json = """
        [{
          "id": "55555555-5555-5555-5555-555555555555",
          "name": "Gofer",
          "startCommand": "gofer start --manifest",
          "startCommandApproved": true
        }]
        """
        let binding = try XCTUnwrap(
            try JSONDecoder().decode([ServiceBinding].self, from: Data(json.utf8)).first
        )
        XCTAssertNil(binding.panelURL)
    }
}

class ServiceCapabilityTests: XCTestCase {
    func testManifestCapabilitiesFollowEndpoints() {
        let binding = ServiceBinding(
            name: "Gofer",
            startCommand: "gofer start --manifest",
            baseURL: URL(string: "http://127.0.0.1:8790"),
            endpoints: ["status": "/status", "pause": "/pause", "resume": "/resume", "stop": "/stop"],
            startCommandApproved: true
        )
        XCTAssertTrue(binding.isProbeable)
        XCTAssertTrue(binding.canStart)
        XCTAssertTrue(binding.canStop)
        XCTAssertTrue(binding.canPause)
        XCTAssertTrue(binding.canResume)
        XCTAssertFalse(binding.canToggle)
    }

    func testManifestWithoutEndpointsIsNotProbeable() {
        let binding = ServiceBinding(name: "Gofer", startCommand: "gofer start", startCommandApproved: true)
        XCTAssertFalse(binding.isProbeable)
    }

    func testLaunchdReadOnlyHidesControls() {
        let binding = ServiceBinding(
            name: "Hermes",
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: true,
            startCommandApproved: true
        )
        XCTAssertTrue(binding.isProbeable)
        XCTAssertFalse(binding.canStart)
        XCTAssertFalse(binding.canStop)
    }

    func testLaunchdControlRequiresApproval() {
        let approved = ServiceBinding(
            name: "Hermes",
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: false,
            startCommandApproved: true
        )
        XCTAssertTrue(approved.canStart)
        XCTAssertTrue(approved.canStop)

        let unapproved = ServiceBinding(
            name: "Hermes",
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: false,
            startCommandApproved: false
        )
        XCTAssertFalse(unapproved.canStart)
        XCTAssertFalse(unapproved.canStop)
    }

    func testProcessCapabilitiesDependOnCommands() {
        let observeOnly = ServiceBinding(
            name: "Hermes",
            kind: .process,
            processPattern: "hermes gateway",
            readOnly: true
        )
        XCTAssertTrue(observeOnly.isProbeable)
        XCTAssertFalse(observeOnly.canStart)
        XCTAssertFalse(observeOnly.canStop)

        let controllable = ServiceBinding(
            name: "Hermes",
            kind: .process,
            processPattern: "hermes gateway",
            readOnly: false,
            stopCommand: "hermes gateway stop",
            startCommandApproved: true
        )
        XCTAssertFalse(controllable.canStart) // no start command
        XCTAssertTrue(controllable.canStop)
    }

    func testPIDFileAlsoMakesProcessProbeable() {
        let binding = ServiceBinding(name: "Worker", kind: .process, pidFile: "/tmp/worker.pid")
        XCTAssertTrue(binding.isProbeable)
    }

    func testCommandKindRequiresStatusCommand() {
        let binding = ServiceBinding(name: "Custom", kind: .command, readOnly: true)
        XCTAssertFalse(binding.isProbeable)
        XCTAssertFalse(binding.canStart)

        let probed = ServiceBinding(name: "Custom", kind: .command, readOnly: true, statusCommand: "true")
        XCTAssertTrue(probed.isProbeable)
    }
}

class ServiceKindStoreTests: XCTestCase {
    private func makeStore() -> ServicesStore {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
        return ServicesStore(
            tokenStore: InMemoryServiceTokenStore(),
            bindingStore: ServiceBindingStore(fileURL: file)
        )
    }

    func testAddLaunchdServiceWithoutStartCommand() {
        let store = makeStore()
        let binding = store.addService(
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true,
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: true
        )

        XCTAssertNotNil(binding)
        XCTAssertEqual(binding?.kind, .launchd)
        XCTAssertEqual(binding?.launchdLabel, "ai.hermes.gateway")
        XCTAssertTrue(binding?.readOnly ?? false)
    }

    func testAddProcessRequiresMatch() {
        let store = makeStore()
        let binding = store.addService(
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true,
            kind: .process
        )
        XCTAssertNil(binding)
        XCTAssertNotNil(store.lastActionError)
    }

    func testAddCommandRequiresStatusCommand() {
        let store = makeStore()
        let binding = store.addService(
            name: "Custom",
            startCommand: "",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true,
            kind: .command
        )
        XCTAssertNil(binding)
        XCTAssertNotNil(store.lastActionError)
    }

    func testLaunchdWithPanelURLGetsOpenPanelImmediately() {
        let store = makeStore()
        let binding = store.addService(
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true,
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: true,
            panelURL: "https://hermes.gateway/router"
        )!

        // The store resolves the explicit panel URL even before the first poll.
        XCTAssertEqual(store.panelURL(for: binding.id)?.absoluteString, "https://hermes.gateway/router")
        // Offline state keeps the URL resolvable but the card disables the button.
        XCTAssertEqual(store.runtime(for: binding.id).state, .offline)
    }

    func testUpdateServiceChangesPanelURL() {
        let store = makeStore()
        let binding = store.addService(
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true,
            kind: .process,
            processPattern: "hermes gateway",
            readOnly: true,
            panelURL: "https://old.gateway/"
        )!

        store.updateService(
            id: binding.id,
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            startCommandApproved: true,
            token: nil,
            kind: .process,
            processPattern: "hermes gateway",
            readOnly: true,
            panelURL: "https://new.gateway/router"
        )

        XCTAssertEqual(store.panelURL(for: binding.id)?.absoluteString, "https://new.gateway/router")
        // A panel URL is a UI target, not a control target: no approval reset.
        XCTAssertTrue(store.binding(for: binding.id)?.startCommandApproved ?? false)
    }

    func testReadOnlyLaunchdStartIsRejected() {
        let store = makeStore()
        let binding = store.addService(
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            token: nil,
            startCommandApproved: true,
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: true
        )!

        store.start(bindingID: binding.id)

        XCTAssertNotNil(store.lastActionError)
        XCTAssertEqual(store.runtime(for: binding.id).state, .offline)
    }

    func testCommandStartAndStopThroughStore() async throws {
        let store = makeStore()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("running")

        let binding = try XCTUnwrap(store.addService(
            name: "Marker",
            startCommand: "touch '\(marker.path)'",
            refreshSeconds: 2,
            token: nil,
            startCommandApproved: true,
            kind: .command,
            readOnly: false,
            statusCommand: "test -f '\(marker.path)'",
            stopCommand: "rm -f '\(marker.path)'"
        ))

        store.start(bindingID: binding.id)
        let running = await waitForState(.running, in: store, id: binding.id)
        XCTAssertTrue(running, store.runtime(for: binding.id).lastError ?? "never became running")
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))

        store.stop(bindingID: binding.id)
        let stopped = await waitForState(.offline, in: store, id: binding.id)
        XCTAssertTrue(stopped, "still \(store.runtime(for: binding.id).state.label)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    private func waitForState(
        _ expected: ServiceState,
        in store: ServicesStore,
        id: UUID,
        attempts: Int = 60
    ) async -> Bool {
        for _ in 0..<attempts {
            let state = await MainActor.run { store.runtime(for: id).state }
            if state == expected { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    func testChangingKindClearsDiscovery() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("services.json")
        let binding = ServiceBinding(
            name: "Gofer",
            startCommand: "gofer start --manifest",
            baseURL: URL(string: "http://127.0.0.1:8790"),
            endpoints: ["status": "/status"],
            serviceID: "gofer",
            startCommandApproved: true
        )
        try ServiceBindingStore(fileURL: file).save([binding])

        let store = ServicesStore(
            tokenStore: InMemoryServiceTokenStore(),
            bindingStore: ServiceBindingStore(fileURL: file)
        )
        store.updateService(
            id: binding.id,
            name: "Hermes",
            startCommand: "",
            refreshSeconds: 5,
            startCommandApproved: true,
            token: nil,
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: true
        )

        let updated = store.binding(for: binding.id)
        XCTAssertEqual(updated?.kind, .launchd)
        XCTAssertNil(updated?.baseURL)
        XCTAssertNil(updated?.endpoints)
        XCTAssertNil(updated?.serviceID)
        XCTAssertEqual(store.runtime(for: binding.id).state, .offline)
    }
}

class LaunchdParsingTests: XCTestCase {
    private let runningOutput = """
    gui/501/ai.hermes.gateway = {
    \tactive count = 1
    \tpath = /Users/kui/Library/LaunchAgents/ai.hermes.gateway.plist
    \tstate = running
    \tprogram = /usr/local/bin/hermes
    \tpid = 4321
    \truns = 3
    \tlast exit code = 0
    }
    """

    private let stoppedOutput = """
    gui/501/ai.hermes.gateway = {
    \tstate = not running
    \truns = 7
    \tlast exit code = 78
    }
    """

    func testParsesRunningJob() throws {
        let job = try XCTUnwrap(LaunchdProvider.parsePrint(runningOutput))
        XCTAssertEqual(job.state, "running")
        XCTAssertEqual(job.pid, 4321)
        XCTAssertEqual(job.runs, 3)
        XCTAssertEqual(job.lastExitStatus, 0)
        XCTAssertTrue(job.isRunning)
    }

    func testParsesStoppedJob() throws {
        let job = try XCTUnwrap(LaunchdProvider.parsePrint(stoppedOutput))
        XCTAssertEqual(job.state, "not running")
        XCTAssertNil(job.pid)
        XCTAssertEqual(job.lastExitStatus, 78)
        XCTAssertFalse(job.isRunning)
    }

    func testNeverExitedHasNoExitStatus() throws {
        let output = """
        gui/501/demo = {
        \tstate = running
        \tpid = 99
        \tlast exit code = (never exited)
        }
        """
        let job = try XCTUnwrap(LaunchdProvider.parsePrint(output))
        XCTAssertEqual(job.pid, 99)
        XCTAssertNil(job.lastExitStatus)
    }

    func testUnparseableOutputIsNotAJob() {
        XCTAssertNil(LaunchdProvider.parsePrint("Bad request."))
    }

    func testParsesLoadedLabels() {
        let output = """
        PID\tStatus\tLabel
        123\t0\thomebrew.mxcl.redis
        -\t0\tcom.apple.Finder
        456\t-9\tai.hermes.gateway
        """
        XCTAssertEqual(
            LaunchdProvider.parseListLabels(output),
            ["ai.hermes.gateway", "homebrew.mxcl.redis"]
        )
    }

    func testMissingJobIsOffline() async throws {
        let binding = ServiceBinding(
            name: "Missing",
            kind: .launchd,
            launchdLabel: "iglance.test.\(UUID().uuidString)",
            readOnly: true
        )
        let probe = try await LaunchdProvider().status(for: binding, token: nil)
        XCTAssertEqual(probe.status.state, "offline")
        XCTAssertNotNil(probe.status.error)
    }

    func testReadOnlyLaunchdStartIsUnsupported() async {
        let binding = ServiceBinding(
            name: "Hermes",
            kind: .launchd,
            launchdLabel: "ai.hermes.gateway",
            readOnly: true
        )
        do {
            _ = try await LaunchdProvider().start(binding)
            XCTFail("Expected read-only start to fail")
        } catch let error as ServiceProviderError {
            guard case .unsupported = error else {
                return XCTFail("Expected unsupported, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

/// Opt-in end-to-end check against a real LaunchAgent.
///
/// Create a plist whose label is `$IGLANCE_TEST_LAUNCHD_LABEL`, bootstrap it
/// into gui/<uid>, then run:
///
///     IGLANCE_TEST_LAUNCHD_LABEL=... swift test --filter LaunchdLifecycleTests
///
/// Without the environment variable the test is skipped, so normal test runs
/// stay deterministic and never touch the user's launchd state.
class LaunchdLifecycleTests: XCTestCase {
    func testRealLaunchdLifecycle() async throws {
        guard let label = ProcessInfo.processInfo.environment["IGLANCE_TEST_LAUNCHD_LABEL"],
              !label.isEmpty else {
            throw XCTSkip("Set IGLANCE_TEST_LAUNCHD_LABEL after bootstrapping a test agent.")
        }

        let provider = LaunchdProvider()
        let binding = ServiceBinding(
            name: "Integration",
            kind: .launchd,
            launchdLabel: label,
            readOnly: false,
            startCommandApproved: true
        )

        let probe = try await provider.status(for: binding, token: nil)
        XCTAssertEqual(probe.status.state, "running", probe.status.error ?? "no error")
        XCTAssertGreaterThan(probe.status.pid ?? 0, 0)
        XCTAssertGreaterThan(probe.memory?.totalRssBytes ?? 0, 0)
        XCTAssertNotNil(probe.status.uptimeSec)
        XCTAssertNil(probe.status.error)

        // Starting an already-running job must be harmless.
        _ = try await provider.start(binding)

        try await provider.perform(.stop, for: binding, token: nil)
        try? await Task.sleep(for: .seconds(1))

        let stopped = try await provider.status(for: binding, token: nil)
        XCTAssertEqual(stopped.status.state, "offline")
        XCTAssertNotNil(stopped.status.error)
    }

    func testStartBringsLoadedJobUp() async throws {
        guard let label = ProcessInfo.processInfo.environment["IGLANCE_TEST_START_LABEL"],
              !label.isEmpty else {
            throw XCTSkip("Set IGLANCE_TEST_START_LABEL to a loaded, on-demand launchd job.")
        }

        let provider = LaunchdProvider()
        let binding = ServiceBinding(
            name: "Startable",
            kind: .launchd,
            launchdLabel: label,
            readOnly: false,
            startCommandApproved: true
        )

        let before = try await provider.status(for: binding, token: nil)
        XCTAssertEqual(before.status.state, "offline")
        XCTAssertNil(before.status.pid)

        _ = try await provider.start(binding)
        try? await Task.sleep(for: .seconds(1))

        let after = try await provider.status(for: binding, token: nil)
        XCTAssertEqual(after.status.state, "running", after.status.error ?? "no error")
        XCTAssertGreaterThan(after.status.pid ?? 0, 0)

        try await provider.perform(.stop, for: binding, token: nil)
    }

    func testLoadedButNotRunningJobIsOffline() async throws {
        guard let label = ProcessInfo.processInfo.environment["IGLANCE_TEST_ONDEMAND_LABEL"],
              !label.isEmpty else {
            throw XCTSkip("Set IGLANCE_TEST_ONDEMAND_LABEL to a loaded, on-demand launchd job.")
        }

        let binding = ServiceBinding(
            name: "OnDemand",
            kind: .launchd,
            launchdLabel: label,
            readOnly: true
        )
        let probe = try await LaunchdProvider().status(for: binding, token: nil)
        XCTAssertEqual(probe.status.state, "offline")
        XCTAssertNil(probe.status.pid)
        XCTAssertNil(probe.memory)
    }

    func testRealSystemDaemonIsObservedButNotControllable() async throws {
        guard let label = ProcessInfo.processInfo.environment["IGLANCE_TEST_SYSTEM_LABEL"],
              !label.isEmpty else {
            throw XCTSkip("Set IGLANCE_TEST_SYSTEM_LABEL to a running system daemon.")
        }

        let provider = LaunchdProvider()
        let binding = ServiceBinding(
            name: "System",
            kind: .launchd,
            launchdLabel: label,
            readOnly: false,
            startCommandApproved: true
        )

        let probe = try await provider.status(for: binding, token: nil)
        XCTAssertEqual(probe.status.state, "running", probe.status.error ?? "no error")
        XCTAssertGreaterThan(probe.status.pid ?? 0, 0)
        XCTAssertGreaterThan(probe.memory?.totalRssBytes ?? 0, 0)

        do {
            _ = try await provider.start(binding)
            XCTFail("System daemons must not be controllable without root")
        } catch let error as ServiceProviderError {
            guard case .unsupported = error else {
                return XCTFail("Expected unsupported, got \(error)")
            }
        }
    }
}

class ProcessParsingTests: XCTestCase {
    func testParsesElapsedFormats() {
        XCTAssertEqual(ProcessInspector.parseElapsed("00:00"), 0)
        XCTAssertEqual(ProcessInspector.parseElapsed("01:02"), 62)
        XCTAssertEqual(ProcessInspector.parseElapsed("01:02:03"), 3_723)
        XCTAssertEqual(ProcessInspector.parseElapsed("2-03:04:05"), 183_845)
        XCTAssertNil(ProcessInspector.parseElapsed("nope"))
    }

    func testParsesPSSample() {
        let output = """
            1  28400 38-11:01:38
        59044   2672       00:00
        """
        let rows = ProcessInspector.parsePSSample(output)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].pid, 1)
        XCTAssertEqual(rows[0].rssBytes, 28_400 * 1024)
        let expectedUptime: Double = 38 * 86_400 + 11 * 3600 + 60 + 38
        XCTAssertEqual(rows[0].uptimeSec, expectedUptime)
        XCTAssertEqual(rows[1].pid, 59_044)
    }

    func testParsesPIDFile() {
        XCTAssertEqual(ProcessInspector.parsePIDFile("  1234  \n"), 1_234)
        XCTAssertEqual(ProcessInspector.parsePIDFile("\n\n42\n"), 42)
        XCTAssertNil(ProcessInspector.parsePIDFile(""))
        XCTAssertNil(ProcessInspector.parsePIDFile("0\n"))
        XCTAssertNil(ProcessInspector.parsePIDFile("not a pid\n"))
    }

    func testParsesIntegerLines() {
        XCTAssertEqual(ProcessInspector.parseIntegerLines("1\n22\n\n333\n"), [1, 22, 333])
        XCTAssertEqual(ProcessInspector.parseIntegerLines(""), [])
    }

    func testPIDFileProviderMeasuresCurrentProcess() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString).pid")
        try "\(getpid())\n".write(to: file, atomically: true, encoding: .utf8)

        let binding = ServiceBinding(
            name: "Test Runner",
            kind: .process,
            pidFile: file.path,
            readOnly: true
        )
        let probe = try await ProcessProvider().status(for: binding, token: nil)

        XCTAssertEqual(probe.status.state, "running")
        XCTAssertEqual(probe.status.pid, Int(getpid()))
        XCTAssertGreaterThan(probe.memory?.totalRssBytes ?? 0, 0)
        XCTAssertNotNil(probe.status.uptimeSec)
    }

    func testPatternMatchingFindsProcess() async throws {
        let marker = UUID().uuidString
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // `sleep 5; true` keeps the shell around (a bare `sleep 5` would be
        // exec'd, dropping the marker from argv and defeating pgrep -f).
        process.arguments = ["-c", "sleep 5; true", marker]
        try process.run()
        defer { process.terminate() }

        let binding = ServiceBinding(
            name: "Pattern",
            kind: .process,
            processPattern: marker,
            readOnly: true
        )
        let provider = ProcessProvider()

        var probe: ServiceProbeResult?
        for _ in 0..<30 {
            probe = try await provider.status(for: binding, token: nil)
            if probe?.status.state == "running" { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertEqual(probe?.status.state, "running")
        XCTAssertEqual(probe?.status.pid, Int(process.processIdentifier))
        XCTAssertGreaterThan(probe?.memory?.totalRssBytes ?? 0, 0)
    }

    func testDescendantsAreIncludedInMemory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pidFile = directory.appendingPathComponent("worker.pid")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "echo $$ > '\(pidFile.path)'; sleep 3 & wait"]
        try process.run()
        defer { process.terminate() }

        let provider = ProcessProvider()
        let binding = ServiceBinding(
            name: "Tree",
            kind: .process,
            pidFile: pidFile.path,
            readOnly: true
        )

        var probe: ServiceProbeResult?
        for _ in 0..<30 {
            probe = try await provider.status(for: binding, token: nil)
            if (probe?.memory?.totalProcesses ?? 0) >= 2 { break }
            try? await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertEqual(probe?.status.state, "running")
        XCTAssertEqual(probe?.status.pid, Int(process.processIdentifier))
        XCTAssertGreaterThanOrEqual(probe?.memory?.totalProcesses ?? 0, 2)
        XCTAssertGreaterThan(probe?.memory?.totalRssBytes ?? 0, 0)
    }
}

class CommandProviderTests: XCTestCase {
    func testExitStatusMeansRunning() async throws {
        let running = ServiceBinding(name: "OK", kind: .command, readOnly: true, statusCommand: "true")
        let probe = try await CommandProvider().status(for: running, token: nil)
        XCTAssertEqual(probe.status.state, "running")
        XCTAssertNil(probe.status.error)
    }

    func testNonZeroExitIsOfflineWithStderr() async throws {
        let failing = ServiceBinding(
            name: "Bad",
            kind: .command,
            readOnly: true,
            statusCommand: "echo boom >&2; exit 3"
        )
        let probe = try await CommandProvider().status(for: failing, token: nil)
        XCTAssertEqual(probe.status.state, "offline")
        XCTAssertTrue(probe.status.error?.contains("boom") ?? false)
    }

    func testJSONStatusIsDecoded() async throws {
        let json = #"{"state":"running","pid":42,"uptime_sec":12.5,"memory":{"available":true,"total_rss_bytes":2048,"total_processes":1}}"#
        let binding = ServiceBinding(
            name: "JSON",
            kind: .command,
            readOnly: true,
            statusCommand: "printf '%s' '\(json)'"
        )
        let probe = try await CommandProvider().status(for: binding, token: nil)
        XCTAssertEqual(probe.status.state, "running")
        XCTAssertEqual(probe.status.pid, 42)
        XCTAssertEqual(probe.status.uptimeSec, 12.5)
        XCTAssertEqual(probe.memory?.totalRssBytes, 2_048)
    }
}

class ServiceLauncherTests: XCTestCase {
    private let manifestLine = #"IGLANCE_SERVICE_MANIFEST {"schema":"iglance.service.v1","service":{"id":"demo","name":"Demo"},"base_url":"http://127.0.0.1:9999","endpoints":{"status":"/status"}}"#

    func testReadsManifestAmongLogs() throws {
        let command = "echo starting; echo '\(manifestLine)'; echo ready"
        let outcome = try ServiceLauncher().launch(bindingID: UUID(), command: command, timeout: 5)
        XCTAssertEqual(outcome.manifest.service.id, "demo")
        XCTAssertEqual(outcome.manifest.baseURL.absoluteString, "http://127.0.0.1:9999")
        XCTAssertEqual(outcome.manifest.endpoints["status"], "/status")
    }

    func testReadsManifestWithoutTrailingNewline() throws {
        let command = "printf '%s' '\(manifestLine)'"
        let outcome = try ServiceLauncher().launch(bindingID: UUID(), command: command, timeout: 5)
        XCTAssertEqual(outcome.manifest.service.id, "demo")
    }

    func testMissingManifestIsReported() {
        XCTAssertThrowsError(
            try ServiceLauncher().launch(bindingID: UUID(), command: "echo hello", timeout: 5)
        ) { error in
            guard case ServiceLaunchError.manifestMissing = error else {
                return XCTFail("Expected manifestMissing, got \(error)")
            }
        }
    }

    func testNonZeroExitIncludesStderr() {
        XCTAssertThrowsError(
            try ServiceLauncher().launch(bindingID: UUID(), command: "echo boom >&2; exit 3", timeout: 5)
        ) { error in
            guard case ServiceLaunchError.exited(let status, let stderr) = error else {
                return XCTFail("Expected exited, got \(error)")
            }
            XCTAssertEqual(status, 3)
            XCTAssertTrue(stderr.contains("boom"))
        }
    }
}

class UpdateTests: XCTestCase {
    func testVersionComparisonIsNumeric() {
        XCTAssertEqual(AppVersion.compare("1.2.3", "1.2.3"), .orderedSame)
        XCTAssertEqual(AppVersion.compare("v1.3.0", "1.2.9"), .orderedDescending)
        XCTAssertEqual(AppVersion.compare("0.9", "1.0"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("1.0", "1.0.1"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("2.0", "10.0"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("1.0.0", "1"), .orderedSame)
    }

    func testVersionComponents() {
        XCTAssertEqual(AppVersion.components(of: "v2.1.0-beta"), [2, 1, 0])
        XCTAssertEqual(AppVersion.components(of: "0.1"), [0, 1])
        XCTAssertEqual(AppVersion.display("v0.1.0"), "0.1.0")
        XCTAssertEqual(AppVersion.display("0.2.0"), "0.2.0")
    }

    func testReleaseDecodingPicksZipAsset() throws {
        let json = """
        {
          "tag_name": "v1.2.0",
          "name": "iGlance 1.2.0",
          "body": "Release notes",
          "html_url": "https://github.com/kuicao55/iGlance/releases/tag/v1.2.0",
          "assets": [
            {"name": "checksums.txt", "browser_download_url": "https://example.com/checksums.txt", "size": 10},
            {"name": "iGlance.app.zip", "browser_download_url": "https://example.com/iGlance.app.zip", "size": 1000}
          ]
        }
        """

        let info = try UpdateService.decodeRelease(from: Data(json.utf8))
        XCTAssertEqual(info.version, "1.2.0")
        XCTAssertEqual(info.tag, "v1.2.0")
        XCTAssertEqual(info.notes, "Release notes")
        XCTAssertEqual(info.assetURL?.lastPathComponent, "iGlance.app.zip")
    }

    func testReleaseDecodingWithoutZipAsset() throws {
        let json = """
        {
          "tag_name": "v1.0.0",
          "name": "iGlance 1.0.0",
          "body": null,
          "html_url": "https://github.com/kuicao55/iGlance/releases/tag/v1.0.0",
          "assets": []
        }
        """

        let info = try UpdateService.decodeRelease(from: Data(json.utf8))
        XCTAssertEqual(info.version, "1.0.0")
        XCTAssertNil(info.assetURL)
        XCTAssertTrue(info.notes.isEmpty)
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
        ProcessRunnerTests.self,
        CPUUsageProviderTests.self,
        MemoryProviderTests.self,
        TemperatureProviderTests.self,
        PowerAssertionServiceTests.self,
        AppStoreTests.self,
        StatusStoreTests.self,
        ServiceManifestParserTests.self,
        ServiceMemoryParsingTests.self,
        ServiceStateTests.self,
        ServiceClientTests.self,
        ServiceBindingStoreTests.self,
        ServicesStoreTests.self,
        ServiceKindMigrationTests.self,
        ServiceCapabilityTests.self,
        ServiceKindStoreTests.self,
        LaunchdParsingTests.self,
        ProcessParsingTests.self,
        CommandProviderTests.self,
        ServiceFormattingTests.self,
        ServiceLauncherTests.self,
        UpdateTests.self
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
