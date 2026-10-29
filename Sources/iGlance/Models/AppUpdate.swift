import Foundation

struct UpdateInfo: Identifiable, Equatable {
    let version: String
    let tag: String
    let title: String
    let notes: String
    let releaseURL: URL
    let assetURL: URL?

    var id: String { tag }
}

struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case size
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }
}
