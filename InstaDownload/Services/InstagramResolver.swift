import Foundation

struct InstagramResolver: Sendable {
    let http: HTTPClient
    let ytDlpAvailable: Bool

    init(http: HTTPClient = URLSessionHTTPClient(), ytDlpAvailable: Bool = YTDlpEngine.locate() != nil) {
        self.http = http
        self.ytDlpAvailable = ytDlpAvailable
    }

    func resolve(_ rawURL: String) async throws -> ResolvedMedia {
        let parsed = try InstagramURL.parse(rawURL)
        let source = try await canonicalize(parsed)

        async let oembedResult = fetchOEmbed(source.pageURL)
        async let embedHTML = fetchHTML(source.embedURL)
        async let pageHTML = fetchHTML(source.pageURL)

        let oembed = await oembedResult
        var parsedEmbed = ParsedEmbed()
        if let embedHTML = await embedHTML {
            parsedEmbed = parsedEmbed.merging(EmbedParser.parse(html: embedHTML))
        }
        if let pageHTML = await pageHTML {
            parsedEmbed = parsedEmbed.merging(EmbedParser.parse(html: pageHTML))
        }

        if parsedEmbed.availability == .privateOrUnavailable && parsedEmbed.videoURL == nil && oembed == nil {
            throw InstaDownloadError.privateOrUnavailable
        }

        let author = firstNonEmpty(oembed?.authorName, parsedEmbed.authorName)
        let title = firstNonEmpty(oembed?.title, parsedEmbed.caption)
        let thumbnail = oembed?.thumbnailURL ?? parsedEmbed.thumbnailURL
        let videoURL = parsedEmbed.videoURL

        if let videoURL {
            return ResolvedMedia(
                source: source,
                authorName: author,
                title: title,
                thumbnailURL: thumbnail,
                videoURL: videoURL,
                engine: .native
            )
        }

        if ytDlpAvailable {
            return ResolvedMedia(
                source: source,
                authorName: author,
                title: title,
                thumbnailURL: thumbnail,
                videoURL: nil,
                engine: .ytDlp
            )
        }

        throw InstaDownloadError.ytDlpMissing
    }

    private func canonicalize(_ link: InstagramURL) async throws -> InstagramURL {
        guard link.kind == .share else { return link }
        let response = try await http.perform(InstagramRequest.page(link.pageURL))
        try validateHTTP(response)
        guard let finalURL = response.url else {
            throw InstaDownloadError.privateOrUnavailable
        }
        if isLoginURL(finalURL) {
            throw InstaDownloadError.privateOrUnavailable
        }
        let resolved = try InstagramURL.parse(finalURL.absoluteString)
        if resolved.kind == .share {
            throw InstaDownloadError.unsupportedLink
        }
        return resolved
    }

    private func fetchHTML(_ url: URL?) async -> String? {
        guard let url else { return nil }
        do {
            let response = try await http.perform(InstagramRequest.page(url))
            if isLoginURL(response.url) { return nil }
            guard (200..<400).contains(response.status) else { return nil }
            return response.text
        } catch {
            return nil
        }
    }

    private func fetchOEmbed(_ url: URL) async -> OEmbedInfo? {
        do {
            let response = try await http.perform(InstagramRequest.oembed(for: url))
            guard (200..<300).contains(response.status) else { return nil }
            guard let object = try JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return nil
            }
            return OEmbedInfo(
                authorName: object["author_name"] as? String,
                title: object["title"] as? String,
                thumbnailURL: (object["thumbnail_url"] as? String).flatMap(URL.init(string:)),
                html: object["html"] as? String
            )
        } catch {
            return nil
        }
    }

    private func validateHTTP(_ response: HTTPResponse) throws {
        if isLoginURL(response.url) {
            throw InstaDownloadError.privateOrUnavailable
        }
        if response.status == 404 || response.status == 403 {
            throw InstaDownloadError.privateOrUnavailable
        }
        if response.status >= 500 {
            throw InstaDownloadError.network("Instagram respondió \(response.status).")
        }
    }

    private func isLoginURL(_ url: URL?) -> Bool {
        guard let path = url?.path.lowercased() else { return false }
        return path.contains("/accounts/login")
    }
}

private func firstNonEmpty(_ values: String?...) -> String? {
    for value in values {
        if let value {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
    }
    return nil
}
