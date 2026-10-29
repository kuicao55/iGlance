import CoreFoundation
import Foundation

/// Reads the temperature sensors macOS publishes through the private
/// IOHIDEventSystemClient API. This is the same sudoless route used by Stats,
/// macmon, and btop; it needs no privileged helper.
final class HIDTemperatureReader {
    struct Reading {
        var cpu: Double?
        var gpu: Double?
        var battery: Double?
        var storage: Double?

        var isEmpty: Bool {
            cpu == nil && gpu == nil && battery == nil && storage == nil
        }
    }

    private struct Symbols {
        let createClient: CreateClientWithType
        let setMatching: SetMatching
        let copyServices: CopyServices
        let copyEvent: CopyEvent
        let getFloatValue: GetFloatValue
        let copyProperty: CopyProperty
    }

    private let lock = NSLock()
    private var client: OpaquePointer?
    private var sensors: [(service: OpaquePointer, name: String)] = []
    private var symbols: Symbols?

    func read() -> Reading {
        lock.lock()
        defer { lock.unlock() }

        guard ensureClient(), let symbols else { return Reading() }

        var cpu: [Double] = []
        var gpu: [Double] = []
        var battery: [Double] = []
        var storage: [Double] = []

        for sensor in sensors {
            guard let event = symbols.copyEvent(sensor.service, 15, 0, 0) else { continue }
            let value = symbols.getFloatValue(event, UInt32(15) << 16)
            guard value.isFinite, value > 1, value < 125 else { continue }

            if sensor.name.hasPrefix("PMU tdie") {
                cpu.append(value)
            } else if sensor.name.hasPrefix("PMU tdev") || sensor.name.localizedCaseInsensitiveContains("GPU") {
                gpu.append(value)
            } else if sensor.name == "gas gauge battery" {
                battery.append(value)
            } else if sensor.name.localizedCaseInsensitiveContains("NAND") {
                storage.append(value)
            }
        }

        return Reading(
            cpu: Self.average(cpu),
            gpu: Self.average(gpu),
            battery: Self.average(battery),
            storage: Self.average(storage)
        )
    }

    private func ensureClient() -> Bool {
        if client != nil {
            return true
        }

        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let create = Self.symbol(handle, "IOHIDEventSystemClientCreateWithType", CreateClientWithType.self),
              let setMatching = Self.symbol(handle, "IOHIDEventSystemClientSetMatching", SetMatching.self),
              let copyServices = Self.symbol(handle, "IOHIDEventSystemClientCopyServices", CopyServices.self),
              let copyEvent = Self.symbol(handle, "IOHIDServiceClientCopyEvent", CopyEvent.self),
              let getFloatValue = Self.symbol(handle, "IOHIDEventGetFloatValue", GetFloatValue.self),
              let copyProperty = Self.symbol(handle, "IOHIDServiceClientCopyProperty", CopyProperty.self)
        else {
            return false
        }

        let symbols = Symbols(
            createClient: create,
            setMatching: setMatching,
            copyServices: copyServices,
            copyEvent: copyEvent,
            getFloatValue: getFloatValue,
            copyProperty: copyProperty
        )

        // Type 1 is kIOHIDEventSystemClientTypeMonitor. The older
        // IOHIDEventSystemClientCreate returns a client without services on
        // recent macOS releases.
        guard let client = create(kCFAllocatorDefault, 1, nil) else { return false }
        setMatching(client, ["PrimaryUsage": 5, "PrimaryUsagePage": 65280] as CFDictionary)
        guard let serviceArray = copyServices(client) else { return false }

        var sensors: [(service: OpaquePointer, name: String)] = []
        for index in 0..<CFArrayGetCount(serviceArray) {
            guard let raw = CFArrayGetValueAtIndex(serviceArray, index) else { continue }
            let service = unsafeBitCast(raw, to: OpaquePointer.self)
            guard let property = copyProperty(service, "Product" as CFString),
                  let name = property as? String
            else { continue }
            sensors.append((service, name))
        }

        self.client = client
        self.symbols = symbols
        self.sensors = sensors
        return true
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String, _ type: T.Type) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

private typealias CreateClientWithType = @convention(c) (CFAllocator?, Int32, CFDictionary?) -> OpaquePointer?
private typealias SetMatching = @convention(c) (OpaquePointer?, CFDictionary?) -> Void
private typealias CopyServices = @convention(c) (OpaquePointer?) -> CFArray?
private typealias CopyEvent = @convention(c) (OpaquePointer?, Int64, Int32, Int64) -> OpaquePointer?
private typealias GetFloatValue = @convention(c) (OpaquePointer?, UInt32) -> Double
private typealias CopyProperty = @convention(c) (OpaquePointer?, CFString?) -> CFTypeRef?
