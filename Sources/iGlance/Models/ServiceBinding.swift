import Foundation

/// How iGlance talks to a service.
///
/// `manifest` is the original `iGlance service.v1` protocol: the start command
/// prints a manifest and the service exposes HTTP endpoints. The other kinds
/// observe and control services that were never written for iGlance.
enum ServiceKind: String, Codable, CaseIterable, Identifiable {
    case manifest
    case launchd
    case process
    case command

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manifest: return "Manifest"
        case .launchd: return "launchd"
        case .process: return "Process"
        case .command: return "Command"
        }
    }

    var explanation: String {
        switch self {
        case .manifest:
            return "A service that prints IGLANCE_SERVICE_MANIFEST and exposes /status, /memory, and /stop."
        case .launchd:
            return "A LaunchAgent or LaunchDaemon managed by launchd. iGlance observes it by label."
        case .process:
            return "Any process group found by a pgrep pattern or a PID file."
        case .command:
            return "A service controlled entirely by your own status, start, and stop commands."
        }
    }
}

/// A user-approved local service. Tokens live in the Keychain, keyed by `id`,
/// and are deliberately not part of this Codable model.
struct ServiceBinding: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var startCommand: String
    var refreshSeconds: Double
    var kind: ServiceKind

    // MARK: launchd
    var launchdLabel: String?

    // MARK: process
    var processPattern: String?
    var pidFile: String?

    // MARK: command / observation
    /// Observe only. No Start/Stop, so iGlance never competes with launchd's
    /// KeepAlive or a supervisor. Defaults to true for launchd bindings.
    var readOnly: Bool

    /// Optional commands for the `process` and `command` kinds.
    var statusCommand: String?
    var stopCommand: String?

    /// The service's web panel, explicitly configured by the user.
    ///
    /// For launchd / process / command bindings this is the only source of the
    /// Open Panel button. For manifest bindings it is a fallback: the URL the
    /// service reports (`urls.panel` / `endpoints.panel`) still wins.
    var panelURL: String?

    // Cached from the last manifest so the service can be polled after a
    // restart without running the start command again. Only used by the
    // `manifest` kind.
    var baseURL: URL?
    var endpoints: [String: String]?
    var auth: ServiceManifestAuth?
    var serviceID: String?
    var serviceVersion: String?

    /// The user has explicitly allowed iGlance to execute the configured
    /// commands and control the service. Manual edits to any control target
    /// reset this.
    var startCommandApproved: Bool

    init(
        id: UUID = UUID(),
        name: String,
        startCommand: String = "",
        refreshSeconds: Double = 5,
        kind: ServiceKind = .manifest,
        launchdLabel: String? = nil,
        processPattern: String? = nil,
        pidFile: String? = nil,
        readOnly: Bool = false,
        statusCommand: String? = nil,
        stopCommand: String? = nil,
        panelURL: String? = nil,
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
        self.kind = kind
        self.launchdLabel = launchdLabel
        self.processPattern = processPattern
        self.pidFile = pidFile
        self.readOnly = readOnly
        self.statusCommand = statusCommand
        self.stopCommand = stopCommand
        self.panelURL = panelURL
        self.baseURL = baseURL
        self.endpoints = endpoints
        self.auth = auth
        self.serviceID = serviceID
        self.serviceVersion = serviceVersion
        self.startCommandApproved = startCommandApproved
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startCommand
        case refreshSeconds
        case kind
        case launchdLabel
        case processPattern
        case pidFile
        case readOnly
        case statusCommand
        case stopCommand
        case panelURL
        case baseURL
        case endpoints
        case auth
        case serviceID
        case serviceVersion
        case startCommandApproved
    }

    /// Hand-written so old `services.json` files without `kind` (and without
    /// any of the newer fields) still decode. The synthesized decoder would
    /// reject them, which used to make `ServiceBindingStore.load()` return an
    /// empty list and silently lose every binding.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startCommand = try container.decodeIfPresent(String.self, forKey: .startCommand) ?? ""

        let interval = try container.decodeIfPresent(Double.self, forKey: .refreshSeconds) ?? 5
        refreshSeconds = max(2, interval)

        // Decode the raw value so an unknown kind written by a newer build
        // falls back to manifest instead of corrupting the whole bindings file.
        let rawKind = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? nil
        let kind = rawKind.flatMap(ServiceKind.init(rawValue:)) ?? .manifest
        self.kind = kind

        launchdLabel = try container.decodeIfPresent(String.self, forKey: .launchdLabel)
        processPattern = try container.decodeIfPresent(String.self, forKey: .processPattern)
        pidFile = try container.decodeIfPresent(String.self, forKey: .pidFile)
        readOnly = try container.decodeIfPresent(Bool.self, forKey: .readOnly) ?? (kind == .launchd)
        statusCommand = try container.decodeIfPresent(String.self, forKey: .statusCommand)
        stopCommand = try container.decodeIfPresent(String.self, forKey: .stopCommand)
        panelURL = try container.decodeIfPresent(String.self, forKey: .panelURL)

        baseURL = try container.decodeIfPresent(URL.self, forKey: .baseURL)
        endpoints = try container.decodeIfPresent([String: String].self, forKey: .endpoints)
        auth = try container.decodeIfPresent(ServiceManifestAuth.self, forKey: .auth)
        serviceID = try container.decodeIfPresent(String.self, forKey: .serviceID)
        serviceVersion = try container.decodeIfPresent(String.self, forKey: .serviceVersion)
        startCommandApproved = try container.decodeIfPresent(Bool.self, forKey: .startCommandApproved) ?? false
    }

    var statusPath: String? { endpoints?["status"] }
    var memoryPath: String? { endpoints?["memory"] }
    var pausePath: String? { endpoints?["pause"] }
    var resumePath: String? { endpoints?["resume"] }
    var togglePath: String? { endpoints?["toggle"] }
    var stopPath: String? { endpoints?["stop"] }

    // MARK: - Control capabilities

    var isProbeable: Bool {
        switch kind {
        case .manifest:
            return baseURL != nil && statusPath?.isEmpty == false
        case .launchd:
            return trimmedLaunchdLabel != nil
        case .process:
            return trimmedProcessPattern != nil || trimmedPIDFile != nil
        case .command:
            return trimmedStatusCommand != nil
        }
    }

    var canStart: Bool {
        guard startCommandApproved, !readOnly else { return false }
        switch kind {
        case .manifest:
            return !trimmedStartCommand.isEmpty
        case .launchd:
            return trimmedLaunchdLabel != nil
        case .process, .command:
            return !trimmedStartCommand.isEmpty
        }
    }

    var canStop: Bool {
        guard startCommandApproved, !readOnly else { return false }
        switch kind {
        case .manifest:
            return stopPath?.isEmpty == false
        case .launchd:
            return trimmedLaunchdLabel != nil
        case .process, .command:
            return trimmedStopCommand != nil
        }
    }

    var canPause: Bool { kind == .manifest && pausePath?.isEmpty == false }
    var canResume: Bool { kind == .manifest && resumePath?.isEmpty == false }
    var canToggle: Bool { kind == .manifest && togglePath?.isEmpty == false }

    var trimmedStartCommand: String { startCommand.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedStopCommand: String? { Self.trimmed(stopCommand) }
    var trimmedStatusCommand: String? { Self.trimmed(statusCommand) }
    var trimmedLaunchdLabel: String? { Self.trimmed(launchdLabel) }
    var trimmedProcessPattern: String? { Self.trimmed(processPattern) }
    var trimmedPIDFile: String? { Self.trimmed(pidFile) }
    var trimmedPanelURL: String? { Self.trimmed(panelURL) }

    /// Changes to anything that decides which service is controlled or what
    /// gets executed. The editor resets the approval toggle when this changes.
    var controlFingerprint: String {
        [
            kind.rawValue,
            startCommand,
            statusCommand ?? "",
            stopCommand ?? "",
            launchdLabel ?? "",
            processPattern ?? "",
            pidFile ?? ""
        ].joined(separator: "\u{1F}")
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    mutating func apply(_ manifest: ServiceManifest) {
        baseURL = manifest.baseURL
        endpoints = manifest.endpoints
        auth = manifest.auth
        serviceID = manifest.service.id
        serviceVersion = manifest.service.version
    }

    /// Drops everything discovered from a previous manifest. Used when the
    /// control target changes.
    mutating func clearDiscovery() {
        baseURL = nil
        endpoints = nil
        auth = nil
        serviceID = nil
        serviceVersion = nil
    }

    /// The service's web UI, if one is available.
    ///
    /// Manifest services keep their original preference order and only fall
    /// back to the explicitly configured `panelURL`: the absolute `urls.panel`
    /// from the last status response (this is the address the service wants
    /// people to use, e.g. a Tailscale name), then the manifest's relative
    /// `panel` path resolved against the status display/base address, then
    /// against the cached `baseURL`. launchd / process / command bindings have
    /// no service-declared panel, so `panelURL` is their only source. Only
    /// http(s) is ever returned, and the token is never added.
    func panelURL(status: ServiceStatusResponse?) -> URL? {
        if kind == .manifest {
            if let raw = status?.urls?.panel,
               let url = Self.webPanelURL(raw) {
                return url
            }

            if let path = endpoints?["panel"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                let baseString = status?.urls?.display
                    ?? status?.urls?.base
                    ?? baseURL?.absoluteString
                if let baseString, let base = URL(string: baseString) {
                    let relative = path.hasPrefix("/") ? path : "/" + path
                    if let url = URL(string: relative, relativeTo: base)?.absoluteURL,
                       Self.isWebURL(url) {
                        return url
                    }
                }
            }
        }

        return Self.webPanelURL(panelURL)
    }

    private static func webPanelURL(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), isWebURL(url) else {
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
