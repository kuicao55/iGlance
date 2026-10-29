import Foundation

enum UpdateError: LocalizedError, Equatable {
    case noRelease
    case http(Int)
    case noAsset
    case invalidBundle
    case notWritable
    case translocated
    case verification(String)

    var errorDescription: String? {
        switch self {
        case .noRelease:
            return "No GitHub releases have been published yet."
        case .http(let code):
            return "GitHub returned HTTP \(code). Try again later."
        case .noAsset:
            return "The latest release does not include a downloadable iGlance.app.zip."
        case .invalidBundle:
            return "The downloaded archive does not contain a valid iGlance.app."
        case .notWritable:
            return "iGlance can't replace itself here. Move iGlance.app to /Applications and try again."
        case .translocated:
            return "iGlance is running from a translocated location. Move it to /Applications and relaunch."
        case .verification(let message):
            return "The update could not be verified: \(message)"
        }
    }
}

final class UpdateService {
    static let repository = "kuicao55/iGlance"
    static let releasesPageURL = URL(string: "https://github.com/\(repository)/releases")!
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestRelease() async throws -> UpdateInfo {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("iGlance/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try Self.decodeRelease(from: data)
    }

    /// Downloads the release ZIP and returns its local URL inside a temp folder.
    func download(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 120

        let (temp, response) = try await session.download(for: request)
        try Self.validate(response)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("iGlanceUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let destination = folder.appendingPathComponent("iGlance-update.zip")
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    static func decodeRelease(from data: Data) throws -> UpdateInfo {
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        // Prefer the app ZIP; other assets (DMG, checksums) aren't installable here.
        let asset = release.assets.first { $0.name.lowercased().hasSuffix(".zip") }

        return UpdateInfo(
            version: AppVersion.display(release.tagName),
            tag: release.tagName,
            title: release.name ?? release.tagName,
            notes: release.body ?? "",
            releaseURL: release.htmlURL,
            assetURL: asset?.browserDownloadURL
        )
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.http(0)
        }
        if http.statusCode == 404 {
            throw UpdateError.noRelease
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UpdateError.http(http.statusCode)
        }
    }
}
