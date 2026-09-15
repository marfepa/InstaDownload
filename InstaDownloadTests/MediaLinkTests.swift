import XCTest
@testable import InstaDownload

final class MediaLinkTests: XCTestCase {
    func testParsesEachPlatform() throws {
        let instagram = try MediaLink.parse("https://www.instagram.com/reel/C8xYz123AbC/")
        XCTAssertEqual(instagram.platform, .instagram)
        XCTAssertEqual(instagram.identifier, "C8xYz123AbC")
        XCTAssertEqual(instagram.displayKind, "Reel")

        let youtube = try MediaLink.parse("https://youtu.be/dQw4w9WgXcQ")
        XCTAssertEqual(youtube.platform, .youtube)
        XCTAssertEqual(youtube.identifier, "dQw4w9WgXcQ")

        let x = try MediaLink.parse("https://x.com/ada_codes/status/1890123456789012345")
        XCTAssertEqual(x.platform, .x)
        XCTAssertEqual(x.identifier, "1890123456789012345")
        XCTAssertEqual(x.authorHint, "ada_codes")
    }

    func testLooksSupported() {
        XCTAssertTrue(MediaLink.looksSupported("https://www.instagram.com/p/AbCdeFGHiJK/"))
        XCTAssertTrue(MediaLink.looksSupported("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        XCTAssertTrue(MediaLink.looksSupported("https://x.com/ada/status/1890123456789012345"))
        XCTAssertFalse(MediaLink.looksSupported("hola"))
        XCTAssertFalse(MediaLink.looksSupported("https://vimeo.com/12345"))
        XCTAssertFalse(MediaLink.looksSupported("https://www.youtube.com/playlist?list=PLabc"))
    }

    func testUnknownSite() {
        XCTAssertThrowsError(try MediaLink.parse("https://vimeo.com/12345")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedSite)
        }
    }
}
