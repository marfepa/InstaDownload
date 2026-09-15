import XCTest
@testable import InstaDownload

final class FilenameSanitizerTests: XCTestCase {
    func testBuildsAuthorAndShortcodeName() {
        let name = FilenameSanitizer.makeFilename(author: "Ada Lovelace", shortcode: "AbCdeFGHiJK")
        XCTAssertEqual(name, "Ada_Lovelace_AbCdeFGHiJK.mp4")
    }

    func testFallsBackWhenEmpty() {
        XCTAssertEqual(FilenameSanitizer.makeFilename(author: nil, shortcode: nil), "instagram-video.mp4")
        XCTAssertEqual(
            FilenameSanitizer.makeFilename(author: nil, shortcode: nil, fallback: "youtube-video"),
            "youtube-video.mp4"
        )
    }

    func testStripsPathSeparators() {
        let name = FilenameSanitizer.makeFilename(author: "../../etc/passwd", shortcode: "code")
        XCTAssertFalse(name.contains("/"))
        XCTAssertTrue(name.hasSuffix(".mp4"))
    }

    func testUniqueURLIncrements() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = FilenameSanitizer.uniqueURL(in: dir, preferredName: "clip.mp4")
        XCTAssertEqual(first.lastPathComponent, "clip.mp4")
        try "a".write(to: first, atomically: true, encoding: .utf8)

        let second = FilenameSanitizer.uniqueURL(in: dir, preferredName: "clip.mp4")
        XCTAssertEqual(second.lastPathComponent, "clip-1.mp4")
    }
}
