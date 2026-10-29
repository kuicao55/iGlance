import Foundation

/// A user-approved local service. Tokens live in the Keychain, keyed by `id`,
/// and are deliberately not part of this Codable model.
struct ServiceBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var startCommand: String
    var refreshSeconds: Double

    // Cached from the last manifest so the service can be polled after a
    // restart without running the start command again.
    var baseURL: URL?
    var endpoints: [String: String]?
    var auth: ServiceManifestAuth?
    var serviceID: String?
    var serviceVersion: String?

    /// The user has explicitly allowed iGlance to execute `startCommand` and
    /// control the service. Manual edits to the command reset this.
    var startCommandApproved: Bool

    init(
        id: UUID = UUID(),
        name: String,
        startCommand: String,
        refreshSeconds: Double = 5,
        baseURL: URL? = nil,
        endpoints: [String: String]? = nil,
        auth: ServiceManifestAuth? = nil,
        serviceID: String? = nil,
        serviceVersion: String? = nil,
        startCommandApproved: Bool = true
    ) {
        self.id = id
        self.name = name
        self.startCommand = startCommand
        self.refreshSeconds = max(2, refreshSeconds)
        self.baseURL = baseURL
        self.endpoints = endpoints
        self.auth = auth
        self.serviceID = serviceID
        self.serviceVersion = serviceVersion
        self.startCommandApproved = startCommandApproved
    }

    var statusPath: String? { endpoints?["status"] }
    var memoryPath: String? { endpoints?["memory"] }
    var pausePath: String? { endpoints?["pause"] }
    var resumePath: String? { endpoints?["resume"] }
    var togglePath: String? { endpoints?["toggle"] }
    var stopPath: String? { endpoints?["stop"] }

    mutating func apply(_ manifest: ServiceManifest) {
        baseURL = manifest.baseURL
        endpoints = manifest.endpoints
        auth = manifest.auth
        serviceID = manifest.service.id
        serviceVersion = manifest.service.version
    }

    /// Drops everything discovered from a previous manifest. Used when the
    /// start command changes.
    mutating func clearDiscovery() {
        baseURL = nil
        endpoints = nil
        auth = nil
        serviceID = nil
        serviceVersion = nil
    }
}
