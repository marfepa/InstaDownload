import Foundation

enum URLParsing {
    static func makeURL(from raw: String, bareHosts: [String]) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = value.lowercased()
        for host in bareHosts where lowered.hasPrefix(host) {
            value = "https://\(value)"
            break
        }
        return URL(string: value)
    }

    static func pathParts(of url: URL) -> [String] {
        url.pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
    }

    static func host(_ url: URL, matches base: String) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == base || host.hasSuffix(".\(base)")
    }

    static func queryValue(_ url: URL, named name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }
}
