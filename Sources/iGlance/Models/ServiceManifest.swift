import Foundation

/// The manifest a service prints on stdout when it is ready.
///
/// One line, prefixed with `IGLANCE_SERVICE_MANIFEST `:
///
///     IGLANCE_SERVICE_MANIFEST {"schema":"iglance.service.v1", ...}
struct ServiceManifest: Codable, Equatable {
    struct Identity: Codable, Equatable {
        let id: String
        let name: String
        let version: String?
        let kind: String?
    }

    let schema: String
    let service: Identity
    let baseURL: URL
    let auth: ServiceManifestAuth?
    let endpoints: [String: String]

    enum CodingKeys: String, CodingKey {
        case schema
        case service
        case baseURL = "base_url"
        case auth
        case endpoints
    }

    init(
        schema: String = ServiceManifestParser.schema,
        service: Identity,
        baseURL: URL,
        auth: ServiceManifestAuth? = nil,
        endpoints: [String: String]
    ) {
        self.schema = schema
        self.service = service
        self.baseURL = baseURL
        self.auth = auth
        self.endpoints = endpoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decode(String.self, forKey: .schema)
        service = try container.decode(Identity.self, forKey: .service)

        let rawBaseURL = try container.decode(String.self, forKey: .baseURL)
        guard let normalized = ServiceManifestParser.normalizedBaseURL(rawBaseURL) else {
            throw ServiceManifestError.invalidBaseURL(rawBaseURL)
        }
        baseURL = normalized

        auth = try container.decodeIfPresent(ServiceManifestAuth.self, forKey: .auth)
        endpoints = try container.decodeIfPresent([String: String].self, forKey: .endpoints) ?? [:]
    }
}

struct ServiceManifestAuth: Codable, Equatable {
    let type: String?
    let header: String?
}

enum ServiceManifestError: LocalizedError, Equatable {
    case missingPrefix
    case missingJSONPayload
    case invalidJSON(String)
    case unsupportedSchema(String)
    case invalidBaseURL(String)

    var errorDescription: String? {
        switch self {
        case .missingPrefix:
            return "No IGLANCE_SERVICE_MANIFEST line was found."
        case .missingJSONPayload:
            return "The IGLANCE_SERVICE_MANIFEST line has no JSON payload."
        case .invalidJSON(let detail):
            return "The service manifest is not valid JSON: \(detail)"
        case .unsupportedSchema(let schema):
            return "Unsupported service schema '\(schema)'. Expected '\(ServiceManifestParser.schema)'."
        case .invalidBaseURL(let raw):
            return "The service manifest has an invalid base_url: \(raw)"
        }
    }
}

enum ServiceManifestParser {
    static let prefix = "IGLANCE_SERVICE_MANIFEST"
    static let schema = "iglance.service.v1"

    /// True when the line is a manifest line, even if its payload is broken.
    static func isManifestLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
    }

    /// The JSON payload of a manifest line, if the line carries one.
    static func jsonPayload(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { return nil }
        let payload = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        guard payload.hasPrefix("{") else { return nil }
        return payload
    }

    static func parse(line: String) throws -> ServiceManifest {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { throw ServiceManifestError.missingPrefix }
        guard let payload = jsonPayload(in: trimmed) else { throw ServiceManifestError.missingJSONPayload }

        let manifest: ServiceManifest
        do {
            manifest = try JSONDecoder().decode(ServiceManifest.self, from: Data(payload.utf8))
        } catch let error as ServiceManifestError {
            throw error
        } catch {
            throw ServiceManifestError.invalidJSON(error.localizedDescription)
        }

        guard manifest.schema == schema else {
            throw ServiceManifestError.unsupportedSchema(manifest.schema)
        }
        return manifest
    }

    /// Find the first valid manifest line in a block of output.
    static func manifest(in output: String) -> ServiceManifest? {
        for line in output.split(whereSeparator: \.isNewline) {
            guard isManifestLine(String(line)) else { continue }
            if let manifest = try? parse(line: String(line)) {
                return manifest
            }
        }
        return nil
    }

    /// Normalizes a base URL: requires http(s), a host, and no trailing slash.
    static func normalizedBaseURL(_ raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        guard !value.isEmpty,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return url
    }

    static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }
}

/// Buffers streamed stdout and hands back complete lines.
struct ServiceLineAccumulator {
    private var buffer = Data()

    mutating func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []

        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newline]
            lines.append(Self.decodeLine(lineData))
            buffer.removeSubrange(buffer.startIndex...newline)
        }

        return lines
    }

    /// The last line when the stream ends without a trailing newline.
    mutating func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        let line = Self.decodeLine(buffer[buffer.startIndex..<buffer.endIndex])
        buffer.removeAll()
        return line
    }

    private static func decodeLine(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
