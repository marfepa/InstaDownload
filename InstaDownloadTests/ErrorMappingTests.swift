import XCTest
@testable import InstaDownload

final class ErrorMappingTests: XCTestCase {
    func testInvalidURLMessage() {
        XCTAssertEqual(
            InstaDownloadError.invalidURL.errorDescription,
            "La URL no es válida. Pega un enlace completo de Instagram, YouTube o X."
        )
        XCTAssertEqual(
            InstaDownloadError.unsupportedSite.errorDescription,
            "Ese enlace no es de Instagram, YouTube ni X."
        )
    }

    func testUnsupportedAndPrivateMessages() {
        XCTAssertTrue(InstaDownloadError.unsupportedLink.errorDescription?.contains("stories") == true)
        XCTAssertTrue(InstaDownloadError.unsupportedLink.errorDescription?.contains("YouTube") == true)
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

    func testYtDlpArgumentsUseFFmpegWhenPresent() {
        let dest = URL(fileURLWithPath: "/tmp/clip.mp4")
        let page = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        let ffmpeg = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")

        let withFFmpeg = YTDlpEngine.arguments(pageURL: page, destination: dest, ffmpegURL: ffmpeg)
        XCTAssertTrue(withFFmpeg.contains("--ffmpeg-location"))
        XCTAssertTrue(withFFmpeg.contains("bv*+ba/b"))
        XCTAssertTrue(withFFmpeg.contains("--merge-output-format"))
        XCTAssertTrue(withFFmpeg.contains("--no-playlist"))

        let without = YTDlpEngine.arguments(pageURL: page, destination: dest, ffmpegURL: nil)
        XCTAssertFalse(without.contains("--ffmpeg-location"))
        XCTAssertEqual(without.first(where: { $0 == "-f" }).map { _ in true }, true)
        XCTAssertTrue(without.contains("b"))
    }

    func testFFmpegMissingAndConversionErrors() {
        XCTAssertTrue(InstaDownloadError.ffmpegMissing.errorDescription?.contains("brew install ffmpeg") == true)
        XCTAssertEqual(InstaDownloadError.ffmpegMissing, InstaDownloadError.ffmpegMissing)
        XCTAssertNotEqual(InstaDownloadError.ffmpegMissing, InstaDownloadError.ytDlpMissing)
        XCTAssertEqual(
            InstaDownloadError.conversionFailed("Error en codec"),
            InstaDownloadError.conversionFailed("Error en codec")
        )
        XCTAssertTrue(InstaDownloadError.conversionFailed("fallo").errorDescription?.contains("fallo") == true)
    }

    func testYtDlpArgumentsForMP3() {
        let dest = URL(fileURLWithPath: "/tmp/clip.mp3")
        let page = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        let ffmpeg = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")

        let args = YTDlpEngine.arguments(pageURL: page, destination: dest, ffmpegURL: ffmpeg, format: .mp3)
        XCTAssertTrue(args.contains("--ffmpeg-location"))
        XCTAssertTrue(args.contains("-x"))
        XCTAssertTrue(args.contains("--audio-format"))
        XCTAssertTrue(args.contains("mp3"))
        XCTAssertFalse(args.contains("--merge-output-format"))
        XCTAssertEqual(args.last, page.absoluteString)
    }
}
