import XCTest
@testable import InstaDownload

final class EmbedParserTests: XCTestCase {
    func testExtractsJSONLDVideo() {
        let html = """
        <html>
        <script type="application/ld+json">
        {"@type":"VideoObject","contentUrl":"https://scontent.cdninstagram.com/v/t50.2886-16/video.mp4?_nc_ht=scontent","thumbnailUrl":"https://scontent.cdninstagram.com/v/t51.2885-15/thumb.jpg","author":{"name":"Ada","alternateName":"ada.codes"},"caption":"Salto a la comba"}
        </script>
        </html>
        """
        let parsed = EmbedParser.parse(html: html)
        XCTAssertEqual(parsed.videoURL?.absoluteString.contains("video.mp4"), true)
        XCTAssertEqual(parsed.thumbnailURL?.pathExtension, "jpg")
        XCTAssertEqual(parsed.authorName, "ada.codes")
        XCTAssertEqual(parsed.caption, "Salto a la comba")
        XCTAssertEqual(parsed.availability, .publicContent)
    }

    func testExtractsOGVideoAndUnescapes() {
        let html = """
        <meta property="og:video" content="https://scontent.cdninstagram.com/v/t50.2886-16/clip.mp4?oe=ABC\\u0026oh=DEF" />
        <meta property="og:title" content="Mario on Instagram: Hello" />
        """
        let parsed = EmbedParser.parse(html: html)
        XCTAssertEqual(parsed.videoURL?.absoluteString.contains("&oh=DEF"), true)
        XCTAssertEqual(parsed.authorName, "Mario")
    }

    func testExtractsHighestVideoVersion() {
        let html = """
        "video_versions":[{"width":240,"url":"https://cdn.example.com/small.mp4"},{"width":720,"url":"https://cdn.example.com/wide.mp4"}]
        """
        let parsed = EmbedParser.parse(html: html)
        XCTAssertEqual(parsed.videoURL?.lastPathComponent, "wide.mp4")
    }

    func testDetectsPrivateAccount() {
        let html = "<html>This account is private. Log in to see the photos.</html>"
        let parsed = EmbedParser.parse(html: html)
        XCTAssertEqual(parsed.availability, .privateOrUnavailable)
        XCTAssertNil(parsed.videoURL)
    }

    func testIgnoresImageURLsAsVideo() {
        let html = #"{"video_url":"https://scontent.cdninstagram.com/v/t51.2885-15/photo.jpg"}"#
        let parsed = EmbedParser.parse(html: html)
        XCTAssertNil(parsed.videoURL)
    }

    func testExtractsXAuthorFromOGTitle() {
        let html = """
        <meta property="og:title" content="Ada on X: Hola mundo" />
        <meta property="og:image" content="https://pbs.twimg.com/media/thumb.jpg" />
        """
        let parsed = EmbedParser.parse(html: html)
        XCTAssertEqual(parsed.authorName, "Ada")
        XCTAssertEqual(parsed.thumbnailURL?.host, "pbs.twimg.com")
    }

    func testDetectsHLSOnly() {
        let html = "playback_url\":\"https://example.com/stream.m3u8\""
        let parsed = EmbedParser.parse(html: html)
        XCTAssertTrue(parsed.hasHLSOnly)
        XCTAssertNil(parsed.videoURL)
    }
}
