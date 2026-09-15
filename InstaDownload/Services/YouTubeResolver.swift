import Foundation

struct YouTubeResolver: Sendable {
    let http: HTTPClient
    let ytDlpAvailable: Bool

    init(http: HTTPClient = URLSessionHTTPClient(), ytDlpAvailable: Bool = YTDlpEngine.locate() != nil) {
        self.http = http
        self.ytDlpAvailable = ytDlpAvailable
    }

    func resolve(_ link: YouTubeURL) async throws -> ResolvedMedia {
        guard ytDlpAvailable else { throw InstaDownloadError.ytDlpMissing }

        let oembed = await fetchOEmbed(link.pageURL)
        return ResolvedMedia(
            source: .youtube(link),
            authorName: oembed?.authorName,
            title: oembed?.title,
            thumbnailURL: oembed?.thumbnailURL,
            videoURL: nil,
            engine: .ytDlp
        )
    }

    private func fetchOEmbed(_ url: URL) async -> OEmbedInfo? {
        do {
            let response = try await http.perform(WebRequest.youtubeOEmbed(for: url))
            guard (200..<300).contains(response.status) else { return nil }
            guard let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return nil
            }
            return OEmbedInfo(
                authorName: object["author_name"] as? String,
                title: object["title"] as? String,
                thumbnailURL: (object["thumbnail_url"] as? String).flatMap(URL.init(string:)),
                html: object["html"] as? String
            )
        } catch {
            return nil
        }
    }
}
