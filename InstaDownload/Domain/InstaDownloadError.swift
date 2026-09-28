import Foundation

enum InstaDownloadError: LocalizedError, Equatable {
    case invalidURL
    case unsupportedSite
    case unsupportedLink
    case noVideo
    case privateOrUnavailable
    case network(String)
    case ytDlpMissing
    case ytDlpFailed(String)
    case ffmpegMissing
    case conversionFailed(String)
    case saveFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL no es válida. Pega un enlace completo de Instagram, YouTube o X."
        case .unsupportedSite:
            return "Ese enlace no es de Instagram, YouTube ni X."
        case .unsupportedLink:
            return "Este tipo de enlace no está soportado. Usa un post, reel o IGTV de Instagram, un vídeo o short de YouTube, o un post de X con vídeo. Las stories, playlists, canales y cuentas privadas quedan fuera."
        case .noVideo:
            return "No hay un vídeo descargable en esa publicación."
        case .privateOrUnavailable:
            return "El contenido no está disponible. Puede ser privado, haberse eliminado o exigir inicio de sesión."
        case .network(let detail):
            return "No se pudo contactar con el servidor. \(detail)"
        case .ytDlpMissing:
            return "Hace falta yt-dlp para descargar este vídeo: brew install yt-dlp"
        case .ytDlpFailed(let detail):
            return "yt-dlp no pudo descargar el vídeo. \(detail)"
        case .ffmpegMissing:
            return "Se requiere ffmpeg para extraer o convertir audio en MP3: brew install ffmpeg"
        case .conversionFailed(let detail):
            return "No se pudo convertir el archivo a MP3. \(detail)"
        case .saveFailed(let detail):
            return "No se pudo guardar el archivo. \(detail)"
        case .cancelled:
            return "Descarga cancelada."
        }
    }

    static func == (lhs: InstaDownloadError, rhs: InstaDownloadError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.unsupportedSite, .unsupportedSite),
             (.unsupportedLink, .unsupportedLink),
             (.noVideo, .noVideo),
             (.privateOrUnavailable, .privateOrUnavailable),
             (.ytDlpMissing, .ytDlpMissing),
             (.ffmpegMissing, .ffmpegMissing),
             (.cancelled, .cancelled):
            return true
        case let (.network(a), .network(b)),
             let (.ytDlpFailed(a), .ytDlpFailed(b)),
             let (.conversionFailed(a), .conversionFailed(b)),
             let (.saveFailed(a), .saveFailed(b)):
            return a == b
        default:
            return false
        }
    }
}
