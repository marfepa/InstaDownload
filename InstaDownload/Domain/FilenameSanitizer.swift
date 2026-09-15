import Foundation

enum FilenameSanitizer {
    static func makeFilename(
        author: String?,
        shortcode: String?,
        fallback: String = "instagram-video",
        ext: String = "mp4"
    ) -> String {
        let pieces = [author, shortcode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(sanitizeComponent)

        let fallbackName = sanitizeComponent(fallback)
        let base = pieces.isEmpty ? (fallbackName.isEmpty ? "video" : fallbackName) : pieces.joined(separator: "_")
        let clipped = String(base.prefix(80))
        let safeExt = sanitizeComponent(ext).isEmpty ? "mp4" : sanitizeComponent(ext)
        return "\(clipped).\(safeExt)"
    }

    static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let fm = FileManager.default
        let ns = preferredName as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        var candidate = directory.appendingPathComponent(preferredName)
        var index = 1
        while fm.fileExists(atPath: candidate.path) {
            let next = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            candidate = directory.appendingPathComponent(next)
            index += 1
        }
        return candidate
    }

    static func sanitizeComponent(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = raw.unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }
            return "_"
        }
        let collapsed = String(mapped)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        return collapsed
    }
}
