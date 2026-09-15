import Foundation

enum EmbedParser {
    static func parse(html: String) -> ParsedEmbed {
        var parsed = ParsedEmbed()
        parsed.availability = detectAvailability(in: html)
        parsed.authorName = extractAuthor(from: html)
        parsed.caption = metaContent(["og:description", "twitter:description"], in: html)
        parsed.thumbnailURL = firstURL(
            [
                metaContent(["og:image", "og:image:url", "twitter:image"], in: html),
                jsonStringValue(forKeys: ["thumbnail_src", "display_url", "thumbnailUrl"], in: html)
            ],
            allowingImages: true
        )

        if let ld = parseJSONLD(in: html) {
            parsed.videoURL = parsed.videoURL ?? ld.videoURL
            parsed.thumbnailURL = parsed.thumbnailURL ?? ld.thumbnailURL
            parsed.authorName = firstNonEmpty(parsed.authorName, ld.authorName)
            parsed.caption = firstNonEmpty(parsed.caption, ld.caption)
        }

        if parsed.videoURL == nil {
            parsed.videoURL = firstURL(
                [
                    metaContent(["og:video:secure_url", "og:video", "og:video:url", "twitter:player:stream"], in: html),
                    jsonStringValue(forKeys: ["video_url", "contentUrl"], in: html),
                    highestQualityVideoVersion(in: html),
                    videoTagSource(in: html)
                ],
                allowingImages: false
            )
        }

        if parsed.videoURL == nil {
            parsed.hasHLSOnly = containsHLS(in: html)
        }

        if parsed.videoURL != nil {
            parsed.availability = .publicContent
        }

        return parsed
    }

    private static func detectAvailability(in html: String) -> ParsedEmbed.Availability {
        let lowered = html.lowercased()
        let privateMarkers = [
            "this account is private",
            "esta cuenta es privada",
            "sorry, this page isn't available",
            "esta página no está disponible",
            "the link may be broken",
            "página no disponible",
            "content isn't available",
            "el contenido no está disponible"
        ]
        if privateMarkers.contains(where: { lowered.contains($0) }) {
            return .privateOrUnavailable
        }
        if lowered.contains("/accounts/login") && !lowered.contains("og:video") && html.count < 20_000 {
            return .privateOrUnavailable
        }
        return .unknown
    }

    private static func extractAuthor(from html: String) -> String? {
        if let ogTitle = metaContent(["og:title"], in: html) {
            if let range = ogTitle.range(of: " on Instagram") {
                let name = String(ogTitle[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
            if let range = ogTitle.range(of: " en Instagram") {
                let name = String(ogTitle[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
            for marker in [" on X:", " on Twitter:", " en X:", " en Twitter:"] {
                if let range = ogTitle.range(of: marker) {
                    let name = String(ogTitle[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { return name }
                }
            }
        }
        return jsonStringValue(forKeys: ["username", "author_name", "alternateName"], in: html)
    }

    private static func parseJSONLD(in html: String) -> ParsedEmbed? {
        let pattern = "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        for match in matches {
            guard match.numberOfRanges > 1, let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonText = String(html[jsonRange])
            guard let data = jsonText.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else { continue }
            let dicts = dictionaries(from: object)
            for dict in dicts {
                let video = stringValue(dict["contentUrl"]).flatMap(cleanedVideoURL)
                let thumb = stringValue(dict["thumbnailUrl"]).flatMap { makeURL($0) }
                var author: String?
                if let authorObject = dict["author"] as? [String: Any] {
                    author = firstNonEmpty(stringValue(authorObject["alternateName"]), stringValue(authorObject["name"]))
                }
                if video != nil || thumb != nil || author != nil {
                    return ParsedEmbed(
                        videoURL: video,
                        thumbnailURL: thumb,
                        authorName: author,
                        caption: stringValue(dict["caption"]) ?? stringValue(dict["description"]),
                        availability: video != nil ? .publicContent : .unknown
                    )
                }
            }
        }
        return nil
    }

    private static func dictionaries(from object: Any) -> [[String: Any]] {
        if let dict = object as? [String: Any] {
            return [dict]
        }
        if let array = object as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }
        return []
    }

    private static func metaContent(_ properties: [String], in html: String) -> String? {
        for property in properties {
            let escaped = NSRegularExpression.escapedPattern(for: property)
            let patterns = [
                "property=[\"']\(escaped)[\"'][^>]*content=[\"']([^\"']+)[\"']",
                "content=[\"']([^\"']+)[\"'][^>]*property=[\"']\(escaped)[\"']",
                "name=[\"']\(escaped)[\"'][^>]*content=[\"']([^\"']+)[\"']"
            ]
            for pattern in patterns {
                if let value = firstCapture(pattern: pattern, in: html) {
                    return decodeHTMLEntities(value)
                }
            }
        }
        return nil
    }

    private static func jsonStringValue(forKeys keys: [String], in html: String) -> String? {
        for key in keys {
            let escaped = NSRegularExpression.escapedPattern(for: key)
            let pattern = "\"\(escaped)\"\\s*:\\s*\"([^\"]+)\""
            if let value = firstCapture(pattern: pattern, in: html) {
                let decoded = unescapeJSON(decodeHTMLEntities(value))
                if !decoded.isEmpty { return decoded }
            }
        }
        return nil
    }

    private static func highestQualityVideoVersion(in html: String) -> String? {
        guard let blockRange = html.range(of: "\"video_versions\"") else { return nil }
        let start = blockRange.lowerBound
        let end = html.index(start, offsetBy: min(8000, html.distance(from: start, to: html.endIndex)), limitedBy: html.endIndex) ?? html.endIndex
        let slice = String(html[start..<end])
        let pattern = "\"url\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(slice.startIndex..., in: slice)
        let urls = regex.matches(in: slice, range: range).compactMap { match -> URL? in
            guard let capture = Range(match.range(at: 1), in: slice) else { return nil }
            return cleanedVideoURL(String(slice[capture]))
        }
        let mp4s = urls.filter { $0.absoluteString.contains(".mp4") || $0.pathExtension.lowercased() == "mp4" }
        return (mp4s.last ?? urls.last)?.absoluteString
    }

    private static func videoTagSource(in html: String) -> String? {
        let patterns = [
            "<video[^>]*src=[\"']([^\"']+)[\"']",
            "<source[^>]*src=[\"']([^\"']+)[\"'][^>]*type=[\"']video"
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern: pattern, in: html) {
                return value
            }
        }
        return nil
    }

    private static func containsHLS(in html: String) -> Bool {
        html.contains(".m3u8") || html.contains("application/x-mpegURL")
    }

    private static func firstCapture(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[capture])
    }

    private static func firstURL(_ candidates: [String?], allowingImages: Bool) -> URL? {
        for candidate in candidates {
            guard let candidate else { continue }
            if allowingImages {
                if let url = makeURL(candidate) { return url }
            } else if let url = cleanedVideoURL(candidate) {
                return url
            }
        }
        return nil
    }

    static func makeURL(_ raw: String) -> URL? {
        let unescaped = unescapeJSON(decodeHTMLEntities(raw))
        guard let url = URL(string: unescaped), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        guard scheme == "https" || scheme == "http" else { return nil }
        return url
    }

    static func cleanedVideoURL(_ raw: String) -> URL? {
        guard let url = makeURL(raw) else { return nil }
        let path = url.absoluteString.lowercased()
        if path.contains(".jpg") || path.contains(".jpeg") || path.contains(".png") || path.contains(".webp") {
            return nil
        }
        return url
    }

    static func unescapeJSON(_ raw: String) -> String {
        var result = raw
        result = result.replacingOccurrences(of: "\\/", with: "/")
        result = result.replacingOccurrences(of: "\\u0026", with: "&")
        result = result.replacingOccurrences(of: "\\u003d", with: "=")
        result = result.replacingOccurrences(of: "\\u0025", with: "%")
        result = result.replacingOccurrences(of: "\\\"", with: "\"")
        if let data = "\"\(result)\"".data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data) {
            return decoded
        }
        return result
    }

    static func decodeHTMLEntities(_ raw: String) -> String {
        var result = raw
        let entities = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">"
        ]
        for (entity, value) in entities {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        return result
    }
}

private func firstNonEmpty(_ a: String?, _ b: String?) -> String? {
    if let a, !a.isEmpty { return a }
    if let b, !b.isEmpty { return b }
    return nil
}

private func stringValue(_ any: Any?) -> String? {
    if let string = any as? String, !string.isEmpty { return string }
    return nil
}
