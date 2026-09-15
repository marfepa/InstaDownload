import Foundation

struct InstagramURL: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case post
        case reel
        case igtv
        case share
    }

    let kind: Kind
    let shortcode: String?
    let original: URL
    let canonicalPageURL: URL
    let embedURL: URL?

    var displayKind: String {
        switch kind {
        case .post: return "Publicación"
        case .reel: return "Reel"
        case .igtv: return "IGTV"
        case .share: return "Enlace compartido"
        }
    }

    var pageURL: URL { canonicalPageURL }

    static func parse(_ raw: String) throws -> InstagramURL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InstaDownloadError.invalidURL }

        guard let url = makeURL(from: trimmed) else {
            throw InstaDownloadError.invalidURL
        }

        guard let host = url.host?.lowercased() else {
            throw InstaDownloadError.invalidURL
        }

        let allowedHosts = [
            "instagram.com",
            "www.instagram.com",
            "m.instagram.com",
            "instagr.am",
            "www.instagr.am"
        ]
        guard allowedHosts.contains(host) else {
            throw InstaDownloadError.notInstagram
        }

        let parts = url.pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

        if parts.first?.lowercased() == "stories" {
            throw InstaDownloadError.unsupportedLink
        }

        if parts.first?.lowercased() == "share" {
            return InstagramURL(
                kind: .share,
                shortcode: nil,
                original: url,
                canonicalPageURL: normalizedInstagramURL(url),
                embedURL: nil
            )
        }

        guard let markerIndex = parts.firstIndex(where: { isMediaMarker($0) }),
              parts.indices.contains(markerIndex + 1) else {
            throw InstaDownloadError.unsupportedLink
        }

        let marker = parts[markerIndex].lowercased()
        let code = parts[markerIndex + 1]
        guard isValidShortcode(code) else {
            throw InstaDownloadError.invalidURL
        }

        let kind: Kind
        switch marker {
        case "reel", "reels":
            kind = .reel
        case "tv":
            kind = .igtv
        default:
            kind = .post
        }

        let canonical = canonicalURL(kind: kind, shortcode: code)
        let embed = embedURL(kind: kind, shortcode: code)
        return InstagramURL(
            kind: kind,
            shortcode: code,
            original: url,
            canonicalPageURL: canonical,
            embedURL: embed
        )
    }

    static func looksLikeInstagram(_ raw: String) -> Bool {
        (try? parse(raw)) != nil
    }

    private static func makeURL(from raw: String) -> URL? {
        var value = raw
        let lowered = value.lowercased()
        if lowered.hasPrefix("instagram.com")
            || lowered.hasPrefix("www.instagram.com")
            || lowered.hasPrefix("m.instagram.com")
            || lowered.hasPrefix("instagr.am")
            || lowered.hasPrefix("www.instagr.am") {
            value = "https://\(value)"
        }
        return URL(string: value)
    }

    private static func isMediaMarker(_ component: String) -> Bool {
        ["p", "reel", "reels", "tv"].contains(component.lowercased())
    }

    private static func isValidShortcode(_ code: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard (5...64).contains(code.count) else { return false }
        return code.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func canonicalURL(kind: Kind, shortcode: String) -> URL {
        let path: String
        switch kind {
        case .reel:
            path = "reel/\(shortcode)/"
        case .igtv:
            path = "tv/\(shortcode)/"
        case .post, .share:
            path = "p/\(shortcode)/"
        }
        return URL(string: "https://www.instagram.com/\(path)")!
    }

    private static func embedURL(kind: Kind, shortcode: String) -> URL {
        let path: String
        switch kind {
        case .reel:
            path = "reel/\(shortcode)/embed/captioned/"
        case .igtv:
            path = "tv/\(shortcode)/embed/captioned/"
        case .post, .share:
            path = "p/\(shortcode)/embed/captioned/"
        }
        return URL(string: "https://www.instagram.com/\(path)")!
    }

    private static func normalizedInstagramURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        if let host = components?.host?.lowercased() {
            if host.hasSuffix("instagram.com") {
                components?.host = "www.instagram.com"
            }
        }
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? url
    }
}
