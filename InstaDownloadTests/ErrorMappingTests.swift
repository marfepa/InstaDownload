import XCTest
@testable import InstaDownload

final class ErrorMappingTests: XCTestCase {
    func testInvalidURLMessage() {
        XCTAssertEqual(
            InstaDownloadError.invalidURL.errorDescription,
            "La URL no es válida. Pega un enlace completo de Instagram."
        )
    }

    func testUnsupportedAndPrivateMessages() {
        XCTAssertTrue(InstaDownloadError.unsupportedLink.errorDescription?.contains("stories") == true)
        XCTAssertTrue(InstaDownloadError.privateOrUnavailable.errorDescription?.contains("privado") == true)
    }

    func testYtDlpMissingMentionsHomebrew() {
        XCTAssertTrue(InstaDownloadError.ytDlpMissing.errorDescription?.contains("brew install yt-dlp") == true)
    }

    func testCancelledAndNoVideo() {
        XCTAssertEqual(InstaDownloadError.cancelled.errorDescription, "Descarga cancelada.")
        XCTAssertEqual(
            InstaDownloadError.noVideo.errorDescription,
            "No hay un vídeo descargable en esa publicación."
        )
    }

    func testProgressParser() throws {
        XCTAssertEqual(try XCTUnwrap(YTDlpEngine.parseProgress("[download]  12.5% of 10MiB")), 0.125, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(YTDlpEngine.parseProgress("[download] 100%")), 1.0, accuracy: 0.0001)
        XCTAssertNil(YTDlpEngine.parseProgress("downloading..."))
    }
}
