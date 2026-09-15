import XCTest
@testable import InstaDownload

final class InstagramURLTests: XCTestCase {
    func testParsesReel() throws {
        let parsed = try InstagramURL.parse("https://www.instagram.com/reel/C8xYz123AbC/")
        XCTAssertEqual(parsed.kind, .reel)
        XCTAssertEqual(parsed.shortcode, "C8xYz123AbC")
        XCTAssertEqual(parsed.pageURL.absoluteString, "https://www.instagram.com/reel/C8xYz123AbC/")
        XCTAssertEqual(parsed.embedURL?.absoluteString, "https://www.instagram.com/reel/C8xYz123AbC/embed/captioned/")
    }

    func testParsesPostWithoutSchemeAndWithQuery() throws {
        let parsed = try InstagramURL.parse("instagram.com/p/AbCdeFGHiJK/?igsh=abc&utm_source=ig")
        XCTAssertEqual(parsed.kind, .post)
        XCTAssertEqual(parsed.shortcode, "AbCdeFGHiJK")
    }

    func testParsesReelsAliasAndUsernamePath() throws {
        let parsed = try InstagramURL.parse("https://www.instagram.com/someone/reels/Short_code-1/")
        XCTAssertEqual(parsed.kind, .reel)
        XCTAssertEqual(parsed.shortcode, "Short_code-1")
    }

    func testParsesIGTV() throws {
        let parsed = try InstagramURL.parse("https://m.instagram.com/tv/TvCode12345/")
        XCTAssertEqual(parsed.kind, .igtv)
        XCTAssertEqual(parsed.shortcode, "TvCode12345")
    }

    func testParsesShareLink() throws {
        let parsed = try InstagramURL.parse("https://www.instagram.com/share/reel/BAQxyz/")
        XCTAssertEqual(parsed.kind, .share)
        XCTAssertNil(parsed.shortcode)
    }

    func testParsesInstagrAm() throws {
        let parsed = try InstagramURL.parse("https://instagr.am/p/AbCdeFGHiJK/")
        XCTAssertEqual(parsed.kind, .post)
        XCTAssertEqual(parsed.shortcode, "AbCdeFGHiJK")
    }

    func testRejectsStories() {
        XCTAssertThrowsError(try InstagramURL.parse("https://www.instagram.com/stories/someone/1234567890/")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
    }

    func testRejectsProfile() {
        XCTAssertThrowsError(try InstagramURL.parse("https://www.instagram.com/cristiano/")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
    }

    func testRejectsNonInstagram() {
        XCTAssertThrowsError(try InstagramURL.parse("https://youtube.com/watch?v=abc")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .notInstagram)
        }
    }

    func testRejectsEmpty() {
        XCTAssertThrowsError(try InstagramURL.parse("   ")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .invalidURL)
        }
    }

    func testLooksLikeInstagram() {
        XCTAssertTrue(InstagramURL.looksLikeInstagram("https://www.instagram.com/reel/C8xYz123AbC/"))
        XCTAssertFalse(InstagramURL.looksLikeInstagram("hola"))
    }
}
