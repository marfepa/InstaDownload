import Foundation

enum InstaDownloadError: LocalizedError, Equatable {
    case invalidURL
    case notInstagram
    case unsupportedLink
    case noVideo
    case privateOrUnavailable
    case network(String)
    case ytDlpMissing
    case ytDlpFailed(String)
    case saveFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL no es válida. Pega un enlace completo de Instagram."
        case .notInstagram:
            return "Ese enlace no es de Instagram."
        case .unsupportedLink:
            return "Este tipo de enlace no está soportado. Usa un post, reel o IGTV público. Las stories y las cuentas privadas quedan fuera."
        case .noVideo:
            return "No hay un vídeo descargable en esa publicación."
        case .privateOrUnavailable:
            return "El contenido no está disponible. Puede ser privado, haberse eliminado o exigir inicio de sesión."
        case .network(let detail):
            return "No se pudo contactar con Instagram. \(detail)"
        case .ytDlpMissing:
            return "El extractor nativo no encontró el vídeo. Instala yt-dlp para más fiabilidad: brew install yt-dlp"
        case .ytDlpFailed(let detail):
            return "yt-dlp no pudo descargar el vídeo. \(detail)"
        case .saveFailed(let detail):
            return "No se pudo guardar el archivo. \(detail)"
        case .cancelled:
            return "Descarga cancelada."
        }
    }

    static func == (lhs: InstaDownloadError, rhs: InstaDownloadError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.notInstagram, .notInstagram),
             (.unsupportedLink, .unsupportedLink),
             (.noVideo, .noVideo),
             (.privateOrUnavailable, .privateOrUnavailable),
             (.ytDlpMissing, .ytDlpMissing),
             (.cancelled, .cancelled):
            return true
        case let (.network(a), .network(b)),
             let (.ytDlpFailed(a), .ytDlpFailed(b)),
             let (.saveFailed(a), .saveFailed(b)):
            return a == b
        default:
            return false
        }
    }
}
