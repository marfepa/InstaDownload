import XCTest
@testable import InstaDownload

final class InstagramResolverTests: XCTestCase {
    func testResolvesDirectVideoFromEmbed() async throws {
        let html = """
        <meta property="og:video" content="https://scontent.cdninstagram.com/v/t50.2886-16/clip.mp4" />
        <meta property="og:title" content="Ada on Instagram: Hola" />
        <meta property="og:image" content="https://scontent.cdninstagram.com/v/t51.2885-15/thumb.jpg" />
        """
        let client = MockHTTPClient { request in
            let url = request.url!.absoluteString
            if url.contains("instagram_oembed") {
                return MockHTTPClient.json(
                    url: request.url!,
                    body: #"{"author_name":"ada.codes","title":"Hola","thumbnail_url":"https://scontent.cdninstagram.com/thumb.jpg"}"#
                )
            }
            return MockHTTPClient.html(url: request.url!, body: html)
        }
        let resolver = InstagramResolver(http: client, ytDlpAvailable: false)
        let media = try await resolver.resolve("https://www.instagram.com/reel/C8xYz123AbC/")
        XCTAssertEqual(media.engine, .native)
        XCTAssertEqual(media.authorName, "ada.codes")
        XCTAssertEqual(media.videoURL?.pathExtension, "mp4")
    }

    func testFallsBackToYTDlpWhenNoDirectVideo() async throws {
        let html = "<html><head><title>Instagram</title></head><body>public post without video tag</body></html>"
        let client = MockHTTPClient { request in
            MockHTTPClient.html(url: request.url!, body: html)
        }
        let resolver = InstagramResolver(http: client, ytDlpAvailable: true)
        let media = try await resolver.resolve("https://www.instagram.com/p/AbCdeFGHiJK/")
        XCTAssertEqual(media.engine, .ytDlp)
        XCTAssertNil(media.videoURL)
    }

    func testAsksForYTDlpWhenNativeExtractionFails() async {
        let html = """
        <meta property="og:title" content="Ada on Instagram: Hola" />
        """
        let client = MockHTTPClient { request in
            if request.url!.absoluteString.contains("instagram_oembed") {
                return MockHTTPClient.json(
                    url: request.url!,
                    body: #"{"author_name":"ada.codes","title":"Hola"}"#
                )
            }
            return MockHTTPClient.html(url: request.url!, body: html)
        }
        let resolver = InstagramResolver(http: client, ytDlpAvailable: false)
        do {
            _ = try await resolver.resolve("https://www.instagram.com/reel/C8xYz123AbC/")
            XCTFail("Expected yt-dlp missing")
        } catch {
            XCTAssertEqual(error as? InstaDownloadError, .ytDlpMissing)
        }
    }

    func testShareRedirectsToReel() async throws {
        let html = """
        <meta property="og:video" content="https://scontent.cdninstagram.com/v/t50.2886-16/clip.mp4" />
        """
        let client = MockHTTPClient { request in
            let url = request.url!.absoluteString
            if url.contains("/share/") {
                return MockHTTPClient.redirect(
                    from: request.url!,
                    to: URL(string: "https://www.instagram.com/reel/C8xYz123AbC/")!
                )
            }
            return MockHTTPClient.html(url: request.url!, body: html)
        }
        let resolver = InstagramResolver(http: client, ytDlpAvailable: false)
        let media = try await resolver.resolve("https://www.instagram.com/share/reel/BAQxyz/")
        XCTAssertEqual(media.source.kind, .reel)
        XCTAssertEqual(media.source.shortcode, "C8xYz123AbC")
        XCTAssertNotNil(media.videoURL)
    }

    func testPrivateContentThrows() async {
        let html = "This account is private"
        let client = MockHTTPClient { request in
            MockHTTPClient.html(url: request.url!, body: html)
        }
        let resolver = InstagramResolver(http: client, ytDlpAvailable: false)
        do {
            _ = try await resolver.resolve("https://www.instagram.com/p/AbCdeFGHiJK/")
            XCTFail("Expected private error")
        } catch {
            XCTAssertEqual(error as? InstaDownloadError, .privateOrUnavailable)
        }
    }
}

struct MockHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) -> HTTPResponse

    func perform(_ request: URLRequest) async throws -> HTTPResponse {
        handler(request)
    }

    static func html(url: URL, body: String, status: Int = 200) -> HTTPResponse {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return HTTPResponse(data: Data(body.utf8), http: response)
    }

    static func json(url: URL, body: String, status: Int = 200) -> HTTPResponse {
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        return HTTPResponse(data: Data(body.utf8), http: response)
    }

    static func redirect(from url: URL, to destination: URL) -> HTTPResponse {
        let response = HTTPURLResponse(url: destination, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        return HTTPResponse(data: Data(), http: response)
    }
}
