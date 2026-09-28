import XCTest
@testable import InstaDownload

final class DownloadFormatTests: XCTestCase {
    func testDownloadFormatProperties() {
        XCTAssertEqual(DownloadFormat.allCases.count, 2)

        let mp4 = DownloadFormat.mp4
        XCTAssertEqual(mp4.id, "mp4")
        XCTAssertEqual(mp4.fileExtension, "mp4")
        XCTAssertEqual(mp4.label, "Vídeo (MP4)")
        XCTAssertEqual(mp4.systemImage, "video")

        let mp3 = DownloadFormat.mp3
        XCTAssertEqual(mp3.id, "mp3")
        XCTAssertEqual(mp3.fileExtension, "mp3")
        XCTAssertEqual(mp3.label, "Audio (MP3)")
        XCTAssertEqual(mp3.systemImage, "music.note")
    }

    func testResolvedMediaSuggestedFilenameWithFormat() throws {
        let link = try MediaLink.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let media = ResolvedMedia(
            source: link,
            authorName: "RickAstley",
            title: "Never Gonna Give You Up",
            thumbnailURL: nil,
            videoURL: nil,
            engine: .ytDlp
        )

        XCTAssertEqual(media.suggestedFilename(for: .mp4), "RickAstley_dQw4w9WgXcQ.mp4")
        XCTAssertEqual(media.suggestedFilename(for: .mp3), "RickAstley_dQw4w9WgXcQ.mp3")
        XCTAssertEqual(media.suggestedFilename, "RickAstley_dQw4w9WgXcQ.mp4")
    }

    @MainActor
    func testViewModelCanDownloadRespectsFFmpegForMP3() throws {
        let link = try MediaLink.parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        let media = ResolvedMedia(
            source: link,
            authorName: "RickAstley",
            title: "Never Gonna Give You Up",
            thumbnailURL: nil,
            videoURL: nil,
            engine: .ytDlp
        )

        // Caso 1: ffmpeg no disponible, mp3 seleccionado -> canDownload debe ser false
        let vmWithoutFFmpeg = DownloadViewModel(
            destination: URL(fileURLWithPath: "/tmp"),
            selectedFormat: .mp3,
            ytDlpAvailable: true,
            ffmpegAvailable: false
        )
        vmWithoutFFmpeg.phase = .ready(media)
        XCTAssertFalse(vmWithoutFFmpeg.canDownload)

        // Cambiar formato a mp4 -> canDownload debe ser true
        vmWithoutFFmpeg.selectedFormat = .mp4
        XCTAssertTrue(vmWithoutFFmpeg.canDownload)

        // Caso 2: ffmpeg disponible, mp3 seleccionado -> canDownload debe ser true
        let vmWithFFmpeg = DownloadViewModel(
            destination: URL(fileURLWithPath: "/tmp"),
            selectedFormat: .mp3,
            ytDlpAvailable: true,
            ffmpegAvailable: true
        )
        vmWithFFmpeg.phase = .ready(media)
        XCTAssertTrue(vmWithFFmpeg.canDownload)
    }

    func testAudioConverterThrowsFFmpegMissingWhenURLNil() async {
        let dummySource = URL(fileURLWithPath: "/tmp/fake.mp4")
        let dummyDest = URL(fileURLWithPath: "/tmp/fake.mp3")

        do {
            try await AudioConverter.convertToMP3(
                source: dummySource,
                destination: dummyDest,
                ffmpegURL: nil
            )
            XCTFail("Debe fallar si no hay binario ffmpeg")
        } catch let error as InstaDownloadError {
            XCTAssertEqual(error, .ffmpegMissing)
        } catch {
            XCTFail("Error inesperado: \(error)")
        }
    }
}
