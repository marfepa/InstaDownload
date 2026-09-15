import Foundation

struct MediaResolver: Sendable {
    let instagram: InstagramResolver
    let youtube: YouTubeResolver
    let x: XResolver

    init(http: HTTPClient = URLSessionHTTPClient(), ytDlpAvailable: Bool = YTDlpEngine.locate() != nil) {
        self.instagram = InstagramResolver(http: http, ytDlpAvailable: ytDlpAvailable)
        self.youtube = YouTubeResolver(http: http, ytDlpAvailable: ytDlpAvailable)
        self.x = XResolver(http: http, ytDlpAvailable: ytDlpAvailable)
    }

    init(instagram: InstagramResolver, youtube: YouTubeResolver, x: XResolver) {
        self.instagram = instagram
        self.youtube = youtube
        self.x = x
    }

    func resolve(_ rawURL: String) async throws -> ResolvedMedia {
        switch try MediaLink.parse(rawURL) {
        case .instagram:
            return try await instagram.resolve(rawURL)
        case .youtube(let link):
            return try await youtube.resolve(link)
        case .x(let link):
            return try await x.resolve(link)
        }
    }
}
