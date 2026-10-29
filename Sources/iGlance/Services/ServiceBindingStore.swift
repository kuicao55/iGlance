import Foundation

/// Persists `ServiceBinding` values as JSON under Application Support.
final class ServiceBindingStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("iGlance", isDirectory: true)
            .appendingPathComponent("services.json")
    }

    func load() -> [ServiceBinding] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([ServiceBinding].self, from: data)
        } catch {
            NSLog("iGlance: failed to read service bindings: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ bindings: [ServiceBinding]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bindings)
        try data.write(to: fileURL, options: [.atomic])
    }
}
