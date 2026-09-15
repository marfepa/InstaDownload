import Foundation

enum MediaLink: Equatable, Sendable {
    enum Platform: String, Equatable, Sendable {
        case instagram
        case youtube
        case x

        var displayName: String {
            switch self {
            case .instagram: return "Instagram"
            case .youtube: return "YouTube"
            case .x: return "X"
            }
        }

        var filenameFallback: String {
            switch self {
            case .instagram: return "instagram-video"
            case .youtube: return "youtube-video"
            case .x: return "x-video"
            }
        }
    }

    case instagram(InstagramURL)
    case youtube(YouTubeURL)
    case x(XURL)

    var platform: Platform {
        switch self {
        case .instagram: return .instagram
        case .youtube: return .youtube
        case .x: return .x
        }
    }

    var pageURL: URL {
        switch self {
        case .instagram(let link): return link.pageURL
        case .youtube(let link): return link.pageURL
        case .x(let link): return link.pageURL
        }
    }

    var identifier: String? {
        switch self {
        case .instagram(let link): return link.shortcode
        case .youtube(let link): return link.videoID
        case .x(let link): return link.statusID
        }
    }

    var authorHint: String? {
        switch self {
        case .instagram: return nil
        case .youtube: return nil
        case .x(let link): return link.username
        }
    }

    var displayKind: String {
        switch self {
        case .instagram(let link): return link.displayKind
        case .youtube(let link): return link.displayKind
        case .x(let link): return link.displayKind
        }
    }

    static func parse(_ raw: String) throws -> MediaLink {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InstaDownloadError.invalidURL }

        if YouTubeURL.matchesHost(trimmed) {
            return .youtube(try YouTubeURL.parse(trimmed))
        }
        if XURL.matchesHost(trimmed) {
            return .x(try XURL.parse(trimmed))
        }
        if InstagramURL.matchesHost(trimmed) {
            return .instagram(try InstagramURL.parse(trimmed))
        }

        if looksLikeWebURL(trimmed) {
            throw InstaDownloadError.unsupportedSite
        }
        throw InstaDownloadError.invalidURL
    }

    static func looksSupported(_ raw: String) -> Bool {
        (try? parse(raw)) != nil
    }

    private static func looksLikeWebURL(_ raw: String) -> Bool {
        let candidate = raw.contains("://") ? raw : "https://\(raw)"
        guard let url = URL(string: candidate), url.host != nil else { return false }
        return raw.contains(".")
    }
}
