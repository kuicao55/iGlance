import Foundation

enum ServiceState: String, Codable, Equatable {
    case running
    case paused
    case offline
    case stopping
    case starting
    case unauthorized
    case unknown

    var label: String {
        switch self {
        case .running: return "Running"
        case .paused: return "Paused"
        case .offline: return "Offline"
        case .stopping: return "Stopping"
        case .starting: return "Starting"
        case .unauthorized: return "Unauthorized"
        case .unknown: return "Unknown"
        }
    }

    static func from(_ response: ServiceStatusResponse?) -> ServiceState {
        guard let response else { return .offline }
        if response.stopping == true { return .stopping }
        if response.paused == true { return .paused }

        switch response.state?.lowercased() {
        case "running": return .running
        case "paused": return .paused
        case "stopping": return .stopping
        case "offline", "stopped": return .offline
        default:
            return response.pid != nil ? .running : .unknown
        }
    }
}

/// Everything known about a binding right now. This is intentionally not
/// persisted; cached connection details live on `ServiceBinding`.
struct ServiceRuntime: Equatable {
    var state: ServiceState = .offline
    var pid: Int?
    var startedAt: Date?
    var uptimeSec: Double?
    var memory: ServiceMemory?
    var lastError: String?
    var lastSeen: Date?
    var isBusy = false
    var manifest: ServiceManifest?

    var isActive: Bool {
        state == .running || state == .paused || state == .stopping
    }
}

// MARK: - Status response

struct ServiceStatusResponse: Decodable {
    let schema: String?
    let ok: Bool?
    let service: ServiceManifest.Identity?
    let state: String?
    let paused: Bool?
    let stopping: Bool?
    let pid: Int?
    let startedAt: Date?
    let uptimeSec: Double?
    let urls: ServiceStatusURLs?
    let auth: ServiceStatusAuth?
    let memory: ServiceMemory?
    let controls: ServiceControls?

    enum CodingKeys: String, CodingKey {
        case schema
        case ok
        case service
        case state
        case paused
        case stopping
        case pid
        case startedAt = "started_at"
        case uptimeSec = "uptime_sec"
        case urls
        case auth
        case memory
        case controls
    }
}

struct ServiceStatusURLs: Decodable, Equatable {
    let base: String?
    let display: String?
    let health: String?
}

struct ServiceStatusAuth: Decodable, Equatable {
    let header: String?
    let tokenRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case header
        case tokenRequired = "token_required"
    }
}

struct ServiceControls: Decodable, Equatable {
    let status: ServiceControlEndpoint?
    let memory: ServiceControlEndpoint?
    let pause: ServiceControlEndpoint?
    let resume: ServiceControlEndpoint?
    let toggle: ServiceControlEndpoint?
    let stop: ServiceControlEndpoint?
}

struct ServiceControlEndpoint: Decodable, Equatable {
    let method: String?
    let path: String?
}

// MARK: - Memory

struct ServiceMemoryGroup: Decodable, Identifiable, Equatable {
    let id: String
    let label: String
    let rssBytes: Int64
    let processes: Int
    let pids: [Int]

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case rssBytes = "rss_bytes"
        case processes
        case pids
    }

    init(id: String, label: String, rssBytes: Int64, processes: Int, pids: [Int]) {
        self.id = id
        self.label = label
        self.rssBytes = rssBytes
        self.processes = processes
        self.pids = pids
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "group"
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? id
        rssBytes = try container.decodeIfPresent(Int64.self, forKey: .rssBytes) ?? 0
        processes = try container.decodeIfPresent(Int.self, forKey: .processes) ?? 0
        pids = try container.decodeIfPresent([Int].self, forKey: .pids) ?? []
    }
}

struct ServiceMemory: Decodable, Equatable {
    let available: Bool
    let source: String?
    let observedAt: Date?
    let totalRssBytes: Int64?
    let totalProcesses: Int?
    let groups: [ServiceMemoryGroup]
    let error: String?

    enum CodingKeys: String, CodingKey {
        case available
        case source
        case error
        case groups
        case observedAt = "observed_at"
        case totalRssBytes = "total_rss_bytes"
        case totalProcesses = "total_processes"

        // Gofer compatibility fields, used only when `groups` is absent.
        case gofer
        case workers
        case xhsBrowser = "xhs_browser"
        case bookingBrowser = "booking_browser"
        case wechat
    }

    init(
        available: Bool,
        source: String? = nil,
        observedAt: Date? = nil,
        totalRssBytes: Int64? = nil,
        totalProcesses: Int? = nil,
        groups: [ServiceMemoryGroup] = [],
        error: String? = nil
    ) {
        self.available = available
        self.source = source
        self.observedAt = observedAt
        self.totalRssBytes = totalRssBytes
        self.totalProcesses = totalProcesses
        self.groups = groups
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        available = try container.decodeIfPresent(Bool.self, forKey: .available) ?? true
        source = try container.decodeIfPresent(String.self, forKey: .source)
        observedAt = try container.decodeIfPresent(Date.self, forKey: .observedAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)

        if let decodedGroups = try container.decodeIfPresent([ServiceMemoryGroup].self, forKey: .groups) {
            groups = decodedGroups
        } else {
            groups = Self.legacyGroups(from: container)
        }

        totalRssBytes = try container.decodeIfPresent(Int64.self, forKey: .totalRssBytes)
            ?? (groups.isEmpty ? nil : groups.reduce(Int64(0)) { $0 + $1.rssBytes })
        totalProcesses = try container.decodeIfPresent(Int.self, forKey: .totalProcesses)
            ?? (groups.isEmpty ? nil : groups.reduce(0) { $0 + $1.processes })
    }

    /// Gofer also returns named groups for compatibility. Other services only
    /// need to return `groups`, but supporting these costs nothing.
    private static func legacyGroups(from container: KeyedDecodingContainer<CodingKeys>) -> [ServiceMemoryGroup] {
        let definitions: [(CodingKeys, String, String)] = [
            (.gofer, "gofer", "Gofer"),
            (.workers, "workers", "Workers"),
            (.xhsBrowser, "xhs_browser", "XHS Browser"),
            (.bookingBrowser, "booking_browser", "Booking Browser"),
            (.wechat, "wechat", "WeChat")
        ]

        return definitions.compactMap { key, id, label in
            guard let group = try? container.decodeIfPresent(ServiceMemoryGroup.self, forKey: key) else {
                return nil
            }
            return ServiceMemoryGroup(
                id: id,
                label: label,
                rssBytes: group.rssBytes,
                processes: group.processes,
                pids: group.pids
            )
        }
    }
}
