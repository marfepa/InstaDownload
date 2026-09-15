import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let http: HTTPURLResponse

    var url: URL? { http.url }
    var status: Int { http.statusCode }
    var text: String { String(data: data, encoding: .utf8) ?? "" }
}

protocol HTTPClient: Sendable {
    func perform(_ request: URLRequest) async throws -> HTTPResponse
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = URLSessionHTTPClient.makeSession()) {
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw InstaDownloadError.network("Respuesta inesperada del servidor.")
            }
            return HTTPResponse(data: data, http: http)
        } catch let error as InstaDownloadError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw InstaDownloadError.cancelled
        } catch {
            throw InstaDownloadError.network(error.localizedDescription)
        }
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpAdditionalHeaders = [
            "User-Agent": InstagramRequest.safariUserAgent,
            "Accept-Language": "es-ES,es;q=0.9,en;q=0.8"
        ]
        return URLSession(configuration: config)
    }
}

enum InstagramRequest {
    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15"

    static func page(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "Referer")
        request.setValue("936619743392459", forHTTPHeaderField: "X-IG-App-ID")
        return request
    }

    static func media(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "Referer")
        request.setValue("video/mp4,video/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        return request
    }

    static func oembed(for instagramURL: URL) -> URLRequest {
        var components = URLComponents(string: "https://graph.facebook.com/v22.0/instagram_oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: instagramURL.absoluteString),
            URLQueryItem(name: "omitscript", value: "true")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(safariUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
