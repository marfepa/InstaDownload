import Foundation

enum DownloadFormat: String, CaseIterable, Identifiable, Sendable {
    case mp4
    case mp3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mp4:
            return "Vídeo (MP4)"
        case .mp3:
            return "Audio (MP3)"
        }
    }

    var systemImage: String {
        switch self {
        case .mp4:
            return "video"
        case .mp3:
            return "music.note"
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4:
            return "mp4"
        case .mp3:
            return "mp3"
        }
    }
}
