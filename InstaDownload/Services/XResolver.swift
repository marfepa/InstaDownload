import Foundation

struct XResolver: Sendable {
    let http: HTTPClient
    let ytDlpAvailable: Bool

    init(http: HTTPClient = URLSessionHTTPClient(), ytDlpAvailable: Bool = YTDlpEngine.locate() != nil) {
        self.http = http
        self.ytDlpAvailable = ytDlpAvailable
    }

    func resolve(_ link: XURL) async throws -> ResolvedMedia {
        guard ytDlpAvailable else { throw InstaDownloadError.ytDlpMissing }

        var parsed = ParsedEmbed()
        if let html = await fetchHTML(link.pageURL) {
            parsed = EmbedParser.parse(html: html)
        }

        return ResolvedMedia(
            source: .x(link),
            authorName: firstNonEmpty(parsed.authorName, link.username),
            title: parsed.caption,
            thumbnailURL: parsed.thumbnailURL,
            videoURL: nil,
            engine: .ytDlp
        )
    }

    private func fetchHTML(_ url: URL) async -> String? {
        do {
            let response = try await http.perform(WebRequest.page(url, referer: "https://x.com/"))
            guard (200..<400).contains(response.status) else { return nil }
            return response.text
        } catch {
            return nil
        }
    }
}

private func firstNonEmpty(_ a: String?, _ b: String?) -> String? {
    if let a {
        let trimmed = a.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
    }
    if let b {
        let trimmed = b.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
    }
    return nil
}
