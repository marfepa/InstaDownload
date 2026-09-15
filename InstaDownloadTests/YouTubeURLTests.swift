import XCTest
@testable import InstaDownload

final class YouTubeURLTests: XCTestCase {
    func testParsesWatchURL() throws {
        let parsed = try YouTubeURL.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=12s")
        XCTAssertEqual(parsed.kind, .video)
        XCTAssertEqual(parsed.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(parsed.pageURL.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testParsesShortLinkWithoutScheme() throws {
        let parsed = try YouTubeURL.parse("youtu.be/dQw4w9WgXcQ?si=abc")
        XCTAssertEqual(parsed.kind, .video)
        XCTAssertEqual(parsed.videoID, "dQw4w9WgXcQ")
    }

    func testParsesShortsAndEmbed() throws {
        let shorts = try YouTubeURL.parse("https://www.youtube.com/shorts/dQw4w9WgXcQ")
        XCTAssertEqual(shorts.kind, .short)
        XCTAssertEqual(shorts.pageURL.absoluteString, "https://www.youtube.com/shorts/dQw4w9WgXcQ")

        let embed = try YouTubeURL.parse("https://www.youtube.com/embed/dQw4w9WgXcQ")
        XCTAssertEqual(embed.kind, .embed)
        XCTAssertEqual(embed.pageURL.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testParsesMobileWatch() throws {
        let parsed = try YouTubeURL.parse("https://m.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(parsed.videoID, "dQw4w9WgXcQ")
    }

    func testRejectsPlaylistAndChannel() {
        XCTAssertThrowsError(try YouTubeURL.parse("https://www.youtube.com/playlist?list=PLabc123")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
        XCTAssertThrowsError(try YouTubeURL.parse("https://www.youtube.com/@handle")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
    }

    func testRejectsInvalidVideoID() {
        XCTAssertThrowsError(try YouTubeURL.parse("https://www.youtube.com/watch?v=abc")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
    }

    func testRejectsNonYouTube() {
        XCTAssertThrowsError(try YouTubeURL.parse("https://www.instagram.com/reel/C8xYz123AbC/")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedSite)
        }
    }
}
