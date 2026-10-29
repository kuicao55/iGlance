import Foundation
import IOKit

/// Reads CPU and GPU die temperatures from AppleSMC.
///
/// AppleSMC reads work without root, but the user client is strict about the
/// structure it receives. The C layout is mirrored here, including the padding
/// that Swift would otherwise omit.
final class SMCTemperatureReader {
    private var connection: io_connect_t = 0
    private let lock = NSLock()

    init() {
        openConnection()
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func cpuTemperature() -> Double? {
        firstTemperature(for: Self.cpuKeys)
    }

    func gpuTemperature() -> Double? {
        firstTemperature(for: Self.gpuKeys)
    }

    private func firstTemperature(for keys: [String]) -> Double? {
        for key in keys {
            if let value = temperature(for: key), value.isFinite, value > 1, value < 125 {
                return value
            }
        }
        return nil
    }

    private func openConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return }
        self.connection = connection
    }

    private func temperature(for key: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard connection != 0, key.utf8.count == 4 else { return nil }

        var infoInput = SMCKeyData()
        infoInput.key = Self.fourCC(key)
        infoInput.data8 = 9  // read key info
        var infoOutput = SMCKeyData()
        var infoSize = MemoryLayout<SMCKeyData>.stride
        guard IOConnectCallStructMethod(
            connection,
            2,
            &infoInput,
            MemoryLayout<SMCKeyData>.stride,
            &infoOutput,
            &infoSize
        ) == KERN_SUCCESS else { return nil }

        let dataSize = infoOutput.keyInfo.dataSize
        guard dataSize > 0 else { return nil }

        var readInput = SMCKeyData()
        readInput.key = infoInput.key
        readInput.keyInfo.dataSize = dataSize
        readInput.data8 = 5  // read bytes
        var readOutput = SMCKeyData()
        var readSize = MemoryLayout<SMCKeyData>.stride
        guard IOConnectCallStructMethod(
            connection,
            2,
            &readInput,
            MemoryLayout<SMCKeyData>.stride,
            &readOutput,
            &readSize
        ) == KERN_SUCCESS else { return nil }

        return Self.decode(type: infoOutput.keyInfo.dataType, size: dataSize, bytes: readOutput.bytes)
    }

    private static func decode(type: UInt32, size: UInt32, bytes: SMCBytes) -> Double? {
        switch typeString(type) {
        case "flt ":
            guard size >= 4 else { return nil }
            let bits = UInt32(bytes.0)
                | UInt32(bytes.1) << 8
                | UInt32(bytes.2) << 16
                | UInt32(bytes.3) << 24
            return Double(Float(bitPattern: bits))
        case "sp78":
            guard size >= 2 else { return nil }
            return Double(Int8(bitPattern: bytes.0)) + Double(bytes.1) / 256.0
        case "fpe2":
            guard size >= 2 else { return nil }
            return Double(UInt16(bytes.0) << 8 | UInt16(bytes.1)) / 4.0
        default:
            return nil
        }
    }

    private static func typeString(_ type: UInt32) -> String {
        let characters = [
            UInt8((type >> 24) & 0xff),
            UInt8((type >> 16) & 0xff),
            UInt8((type >> 8) & 0xff),
            UInt8(type & 0xff)
        ]
        return String(bytes: characters, encoding: .ascii) ?? ""
    }

    private static func fourCC(_ key: String) -> UInt32 {
        key.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private static let cpuKeys = [
        "TCMz",  // CPU die hotspot
        "TCMb",  // CPU die average
        "TC0D", "TC0E", "TC0F", "TC0H", "TC0P"
    ]

    private static let gpuKeys = [
        "TRDX",  // GPU die hotspot
        "TGDD", "TG0D", "TG0P",
        "Tg0D", "Tg0U", "Tg0X", "Tg0d", "Tg0e", "Tg0f", "Tg0g",
        "Tg0h", "Tg0i", "Tg0j", "Tg0k", "Tg0l", "Tg0m", "Tg0n",
        "Tg0o", "Tg0p", "Tg0q", "Tg0r"
    ]
}

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimit {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

/// Explicit trailing padding keeps the C struct's 80-byte layout.
private struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var pad0: UInt8 = 0
    var pad1: UInt8 = 0
    var pad2: UInt8 = 0
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimit = SMCPLimit()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var pad: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}
