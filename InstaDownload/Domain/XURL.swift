import Foundation

struct XURL: Equatable, Sendable {
    let username: String?
    let statusID: String
    let original: URL
    let canonicalPageURL: URL

    var pageURL: URL { canonicalPageURL }
    var displayKind: String { "Post de X" }

    static func parse(_ raw: String) throws -> XURL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InstaDownloadError.invalidURL }
        guard let url = makeURL(from: trimmed) else { throw InstaDownloadError.invalidURL }
        guard matchesHost(url) else { throw InstaDownloadError.unsupportedSite }

        let parts = URLParsing.pathParts(of: url)
        guard parts.count >= 3 else { throw InstaDownloadError.unsupportedLink }

        let statusMarker = parts[1].lowercased()
        guard statusMarker == "status" || statusMarker == "statuses" else {
            throw InstaDownloadError.unsupportedLink
        }

        let statusID = parts[2]
        guard isValidStatusID(statusID) else { throw InstaDownloadError.invalidURL }

        let userPart = parts[0]
        let username: String?
        if userPart.lowercased() == "i" {
            username = nil
        } else {
            guard isValidUsername(userPart) else { throw InstaDownloadError.invalidURL }
            username = userPart
        }

        let canonicalPath = username.map { "\($0)/status/\(statusID)" } ?? "i/status/\(statusID)"
        return XURL(
            username: username,
            statusID: statusID,
            original: url,
            canonicalPageURL: URL(string: "https://x.com/\(canonicalPath)")!
        )
    }

    static func matchesHost(_ raw: String) -> Bool {
        guard let url = makeURL(from: raw) else { return false }
        return matchesHost(url)
    }

    static func matchesHost(_ url: URL) -> Bool {
        URLParsing.host(url, matches: "x.com") || URLParsing.host(url, matches: "twitter.com")
    }

    private static func makeURL(from raw: String) -> URL? {
        URLParsing.makeURL(from: raw, bareHosts: [
            "x.com",
            "www.x.com",
            "twitter.com",
            "www.twitter.com",
            "mobile.twitter.com",
            "mobile.x.com"
        ])
    }

    private static func isValidStatusID(_ value: String) -> Bool {
        guard (5...32).contains(value.count) else { return false }
        return value.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    private static func isValidUsername(_ value: String) -> Bool {
        guard (1...64).contains(value.count) else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
