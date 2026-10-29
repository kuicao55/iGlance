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

    /// The service's web UI, if it exposes one.
    ///
    /// Preference order: the absolute `urls.panel` from the last status
    /// response (this is the address the service wants people to use, e.g. a
    /// Tailscale name), then the manifest's relative `panel` path resolved
    /// against the status display/base address, then against the cached
    /// `baseURL`. Only http(s) is ever returned, and the token is never added.
    func panelURL(status: ServiceStatusResponse?) -> URL? {
        if let raw = status?.urls?.panel,
           let url = URL(string: raw),
           Self.isWebURL(url) {
            return url
        }

        guard let path = endpoints?["panel"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }

        let baseString = status?.urls?.display
            ?? status?.urls?.base
            ?? baseURL?.absoluteString
        guard let baseString, let base = URL(string: baseString) else { return nil }

        let relative = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: relative, relativeTo: base)?.absoluteURL,
              Self.isWebURL(url) else {
            return nil
        }
        return url
    }

    private static func isWebURL(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https": return true
        default: return false
        }
    }
}
