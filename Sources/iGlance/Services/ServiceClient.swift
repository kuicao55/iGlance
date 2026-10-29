import Foundation

enum ServiceControlAction: String {
    case pause
    case resume
    case toggle
    case stop
}

enum ServiceClientError: LocalizedError, Equatable {
    case missingBaseURL
    case missingEndpoint(String)
    case invalidURL
    case unauthorized
    case connectionFailed(String)
    case server(status: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "No base URL is known yet. Start the service once to read its manifest."
        case .missingEndpoint(let name):
            return "The service manifest has no '\(name)' endpoint."
        case .invalidURL:
            return "The service URL is invalid."
        case .unauthorized:
            return "The service rejected the token (401). Check the token in Edit Service."
        case .connectionFailed(let detail):
            return "Can't reach the service: \(detail)"
        case .server(let status, let message):
            return "The service returned HTTP \(status): \(message)"
        case .decoding(let detail):
            return "The service response could not be read: \(detail)"
        }
    }

    var isConnectionFailure: Bool {
        if case .connectionFailed = self { return true }
        return false
    }

    var isUnauthorized: Bool {
        self == .unauthorized
    }

    static func map(_ error: Error) -> ServiceClientError {
        if let error = error as? ServiceClientError {
            return error
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
                 .notConnectedToInternet, .timedOut, .dnsLookupFailed:
                return .connectionFailed(urlError.localizedDescription)
            default:
                return .connectionFailed(urlError.localizedDescription)
            }
        }
        return .connectionFailed(error.localizedDescription)
    }
}

final class ServiceClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 2
            configuration.timeoutIntervalForResource = 4
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: - Requests

    func fetchStatus(binding: ServiceBinding, token: String?) async throws -> ServiceStatusResponse {
        guard let path = binding.statusPath, !path.isEmpty else {
            throw ServiceClientError.missingEndpoint("status")
        }
        let data = try await request(
            baseURL: binding.baseURL,
            path: path,
            method: "GET",
            token: token,
            auth: binding.auth
        )
        return try decode(ServiceStatusResponse.self, from: data)
    }

    func fetchMemory(binding: ServiceBinding, token: String?) async throws -> ServiceMemory {
        guard let path = binding.memoryPath, !path.isEmpty else {
            throw ServiceClientError.missingEndpoint("memory")
        }
        let data = try await request(
            baseURL: binding.baseURL,
            path: path,
            method: "GET",
            token: token,
            auth: binding.auth
        )
        return try decode(ServiceMemory.self, from: data)
    }

    func perform(_ action: ServiceControlAction, binding: ServiceBinding, token: String?) async throws {
        guard let path = endpointPath(for: action, binding: binding) else {
            throw ServiceClientError.missingEndpoint(action.rawValue)
        }

        var queryItems: [URLQueryItem] = []
        if action == .stop {
            queryItems = [
                URLQueryItem(name: "cleanup", value: "true"),
                URLQueryItem(name: "close_browser", value: "true")
            ]
        }

        _ = try await request(
            baseURL: binding.baseURL,
            path: path,
            method: "POST",
            queryItems: queryItems,
            token: token,
            auth: binding.auth
        )
    }

    func fetchStatus(baseURL: URL, endpoints: [String: String], auth: ServiceManifestAuth?, token: String?) async throws -> ServiceStatusResponse {
        guard let path = endpoints["status"], !path.isEmpty else {
            throw ServiceClientError.missingEndpoint("status")
        }
        let data = try await request(
            baseURL: baseURL,
            path: path,
            method: "GET",
            token: token,
            auth: auth
        )
        return try decode(ServiceStatusResponse.self, from: data)
    }

    // MARK: - Helpers

    private func endpointPath(for action: ServiceControlAction, binding: ServiceBinding) -> String? {
        switch action {
        case .pause: return binding.pausePath
        case .resume: return binding.resumePath
        case .toggle: return binding.togglePath
        case .stop: return binding.stopPath
        }
    }

    private func request(
        baseURL: URL?,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        token: String?,
        auth: ServiceManifestAuth?
    ) async throws -> Data {
        guard let baseURL else { throw ServiceClientError.missingBaseURL }
        guard let url = Self.buildURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw ServiceClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 2
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in Self.authHeaders(token: token, auth: auth) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceClientError.map(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ServiceClientError.server(status: -1, message: "Not an HTTP response")
        }

        if http.statusCode == 401 {
            throw ServiceClientError.unauthorized
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = body.isEmpty
                ? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                : String(body.prefix(300))
            throw ServiceClientError.server(status: http.statusCode, message: message)
        }

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try ServiceJSON.decoder.decode(type, from: data)
        } catch {
            throw ServiceClientError.decoding(error.localizedDescription)
        }
    }

    static func buildURL(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) -> URL? {
        var base = baseURL.absoluteString
        while base.hasSuffix("/") {
            base.removeLast()
        }
        let suffix = path.hasPrefix("/") ? path : "/" + path

        guard var components = URLComponents(string: base + suffix) else { return nil }
        if !queryItems.isEmpty {
            var items = components.queryItems ?? []
            items.append(contentsOf: queryItems)
            components.queryItems = items
        }
        return components.url
    }

    static func authHeaders(token: String?, auth: ServiceManifestAuth?) -> [String: String] {
        guard let token, !token.isEmpty else { return [:] }
        if auth?.type?.lowercased() == "none" { return [:] }

        let header: String
        if let name = auth?.header, !name.isEmpty {
            header = name
        } else {
            header = "Authorization"
        }
        if header.caseInsensitiveCompare("Authorization") == .orderedSame {
            return [header: "Bearer \(token)"]
        }
        return [header: token]
    }
}
