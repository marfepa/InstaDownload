import XCTest
@testable import InstaDownload

final class XURLTests: XCTestCase {
    func testParsesStatus() throws {
        let parsed = try XURL.parse("https://x.com/ada_codes/status/1890123456789012345?s=20")
        XCTAssertEqual(parsed.username, "ada_codes")
        XCTAssertEqual(parsed.statusID, "1890123456789012345")
        XCTAssertEqual(parsed.pageURL.absoluteString, "https://x.com/ada_codes/status/1890123456789012345")
    }

    func testParsesTwitterAndMobileHosts() throws {
        let twitter = try XURL.parse("https://twitter.com/ada_codes/status/1890123456789012345")
        XCTAssertEqual(twitter.statusID, "1890123456789012345")

        let mobile = try XURL.parse("https://mobile.twitter.com/ada_codes/status/1890123456789012345")
        XCTAssertEqual(mobile.username, "ada_codes")
    }

    func testParsesBareHostAndIStatus() throws {
        let parsed = try XURL.parse("x.com/i/status/1890123456789012345")
        XCTAssertNil(parsed.username)
        XCTAssertEqual(parsed.statusID, "1890123456789012345")
        XCTAssertEqual(parsed.pageURL.absoluteString, "https://x.com/i/status/1890123456789012345")
    }

    func testRejectsProfileAndSpaces() {
        XCTAssertThrowsError(try XURL.parse("https://x.com/ada_codes")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
        XCTAssertThrowsError(try XURL.parse("https://x.com/i/spaces/1ABC")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedLink)
        }
    }

    func testRejectsNonX() {
        XCTAssertThrowsError(try XURL.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ")) { error in
            XCTAssertEqual(error as? InstaDownloadError, .unsupportedSite)
        }
    }
}
