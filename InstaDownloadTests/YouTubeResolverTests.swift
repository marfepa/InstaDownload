import XCTest
@testable import InstaDownload

final class YouTubeResolverTests: XCTestCase {
    func testResolvesOEmbedPreview() async throws {
        let client = MockHTTPClient { request in
            XCTAssertTrue(request.url!.absoluteString.contains("oembed"))
            return MockHTTPClient.json(
                url: request.url!,
                body: #"{"author_name":"Rick","title":"Never Gonna Give You Up","thumbnail_url":"https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"}"#
            )
        }
        let resolver = YouTubeResolver(http: client, ytDlpAvailable: true)
        let link = try YouTubeURL.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let media = try await resolver.resolve(link)
        XCTAssertEqual(media.engine, .ytDlp)
        XCTAssertEqual(media.authorName, "Rick")
        XCTAssertEqual(media.title, "Never Gonna Give You Up")
        XCTAssertEqual(media.thumbnailURL?.host, "i.ytimg.com")
        XCTAssertNil(media.videoURL)
        XCTAssertEqual(media.source.platform, .youtube)
        XCTAssertTrue(media.suggestedFilename.contains("Rick"))
    }

    func testRequiresYTDlp() async throws {
        let client = MockHTTPClient { _ in
            MockHTTPClient.json(url: URL(string: "https://www.youtube.com/oembed")!, body: "{}")
        }
        let resolver = YouTubeResolver(http: client, ytDlpAvailable: false)
        let link = try YouTubeURL.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        do {
            _ = try await resolver.resolve(link)
            XCTFail("Expected yt-dlp missing")
        } catch {
            XCTAssertEqual(error as? InstaDownloadError, .ytDlpMissing)
        }
    }

    func testMediaResolverRoutesYouTubeAndX() async throws {
        let client = MockHTTPClient { request in
            let url = request.url!.absoluteString
            if url.contains("oembed") {
                return MockHTTPClient.json(
                    url: request.url!,
                    body: #"{"author_name":"Rick","title":"Song"}"#
                )
            }
            return MockHTTPClient.html(
                url: request.url!,
                body: """
                <meta property="og:title" content="Ada on X: Hola" />
                <meta property="og:image" content="https://pbs.twimg.com/media/thumb.jpg" />
                """
            )
        }
        let resolver = MediaResolver(http: client, ytDlpAvailable: true)

        let youtube = try await resolver.resolve("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(youtube.source.platform, .youtube)
        XCTAssertEqual(youtube.authorName, "Rick")

        let x = try await resolver.resolve("https://x.com/ada_codes/status/1890123456789012345")
        XCTAssertEqual(x.source.platform, .x)
        XCTAssertEqual(x.engine, .ytDlp)
        XCTAssertEqual(x.authorName, "Ada")
    }
}
