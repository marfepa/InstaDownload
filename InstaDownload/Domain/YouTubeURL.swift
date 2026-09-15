import Foundation

struct YouTubeURL: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case video
        case short
        case embed
    }

    let kind: Kind
    let videoID: String
    let original: URL
    let canonicalPageURL: URL

    var pageURL: URL { canonicalPageURL }

    var displayKind: String {
        switch kind {
        case .video: return "YouTube"
        case .short: return "Short"
        case .embed: return "YouTube"
        }
    }

    static func parse(_ raw: String) throws -> YouTubeURL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InstaDownloadError.invalidURL }
        guard let url = makeURL(from: trimmed) else { throw InstaDownloadError.invalidURL }
        guard matchesHost(url) else { throw InstaDownloadError.unsupportedSite }

        if isYoutuBe(url), let id = URLParsing.pathParts(of: url).first, isValidVideoID(id) {
            return make(kind: .video, videoID: id, original: url)
        }

        let parts = URLParsing.pathParts(of: url)

        if let id = firstID(after: "shorts", in: parts), isValidVideoID(id) {
            return make(kind: .short, videoID: id, original: url)
        }
        if let id = firstID(after: "embed", in: parts), isValidVideoID(id) {
            return make(kind: .embed, videoID: id, original: url)
        }
        if let id = firstID(after: "live", in: parts), isValidVideoID(id) {
            return make(kind: .video, videoID: id, original: url)
        }
        if let id = firstID(after: "v", in: parts), isValidVideoID(id) {
            return make(kind: .video, videoID: id, original: url)
        }
        if let id = URLParsing.queryValue(url, named: "v"), isValidVideoID(id) {
            return make(kind: .video, videoID: id, original: url)
        }

        throw InstaDownloadError.unsupportedLink
    }

    static func matchesHost(_ raw: String) -> Bool {
        guard let url = makeURL(from: raw) else { return false }
        return matchesHost(url)
    }

    static func matchesHost(_ url: URL) -> Bool {
        URLParsing.host(url, matches: "youtube.com") || URLParsing.host(url, matches: "youtu.be")
    }

    private static func isYoutuBe(_ url: URL) -> Bool {
        URLParsing.host(url, matches: "youtu.be")
    }

    private static func makeURL(from raw: String) -> URL? {
        URLParsing.makeURL(from: raw, bareHosts: [
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "youtu.be",
            "www.youtu.be"
        ])
    }

    private static func firstID(after marker: String, in parts: [String]) -> String? {
        guard let index = parts.firstIndex(where: { $0.lowercased() == marker }),
              parts.indices.contains(index + 1) else {
            return nil
        }
        return parts[index + 1]
    }

    private static func isValidVideoID(_ value: String) -> Bool {
        guard value.count == 11 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func make(kind: Kind, videoID: String, original: URL) -> YouTubeURL {
        let canonical: URL
        if kind == .short {
            canonical = URL(string: "https://www.youtube.com/shorts/\(videoID)")!
        } else {
            canonical = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
        }
        return YouTubeURL(
            kind: kind,
            videoID: videoID,
            original: original,
            canonicalPageURL: canonical
        )
    }
}
