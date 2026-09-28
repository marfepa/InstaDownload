import Foundation

struct ResolvedMedia: Equatable, Sendable {
    enum Engine: String, Equatable, Sendable {
        case native
        case ytDlp
    }

    let source: MediaLink
    let authorName: String?
    let title: String?
    let thumbnailURL: URL?
    let videoURL: URL?
    let engine: Engine

    func suggestedFilename(for format: DownloadFormat = .mp4) -> String {
        FilenameSanitizer.makeFilename(
            author: authorName ?? source.authorHint,
            shortcode: source.identifier,
            fallback: source.platform.filenameFallback,
            ext: format.fileExtension
        )
    }

    var suggestedFilename: String {
        suggestedFilename(for: .mp4)
    }
}

struct OEmbedInfo: Equatable, Sendable {
    var authorName: String?
    var title: String?
    var thumbnailURL: URL?
    var html: String?
}

struct ParsedEmbed: Equatable, Sendable {
    var videoURL: URL?
    var thumbnailURL: URL?
    var authorName: String?
    var caption: String?
    var hasHLSOnly: Bool = false
    var availability: Availability = .unknown

    enum Availability: Equatable, Sendable {
        case unknown
        case publicContent
        case privateOrUnavailable
    }

    func merging(_ other: ParsedEmbed) -> ParsedEmbed {
        var copy = self
        copy.videoURL = copy.videoURL ?? other.videoURL
        copy.thumbnailURL = copy.thumbnailURL ?? other.thumbnailURL
        copy.authorName = firstNonEmpty(copy.authorName, other.authorName)
        copy.caption = firstNonEmpty(copy.caption, other.caption)
        copy.hasHLSOnly = copy.hasHLSOnly || other.hasHLSOnly
        if copy.availability == .unknown {
            copy.availability = other.availability
        } else if other.availability == .privateOrUnavailable {
            copy.availability = .privateOrUnavailable
        }
        return copy
    }
}

private func firstNonEmpty(_ a: String?, _ b: String?) -> String? {
    if let a, !a.isEmpty { return a }
    if let b, !b.isEmpty { return b }
    return nil
}
