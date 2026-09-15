import Foundation

struct YTDlpEngine: Sendable {
    let executableURL: URL

    init?(executableURL: URL? = YTDlpEngine.locate()) {
        guard let executableURL else { return nil }
        self.executableURL = executableURL
    }

    static func locate() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/opt/local/bin/yt-dlp",
            "\(NSHomeDirectory())/.local/bin/yt-dlp"
        ]
        let fm = FileManager.default
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    func download(
        instagramURL: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--no-playlist",
            "--newline",
            "--no-warnings",
            "--no-mtime",
            "-f", "b",
            "-o", destination.path,
            instagramURL.absoluteString
        ]
        process.environment = mergedEnvironment()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                stdout.fileHandleForReading.readabilityHandler = { handle in
                    let text = String(data: handle.availableData, encoding: .utf8) ?? ""
                    if let value = Self.parseProgress(text) {
                        progress(value)
                    }
                }
                stderr.fileHandleForReading.readabilityHandler = { handle in
                    let text = String(data: handle.availableData, encoding: .utf8) ?? ""
                    if let value = Self.parseProgress(text) {
                        progress(value)
                    }
                }
                process.terminationHandler = { finished in
                    stdout.fileHandleForReading.readabilityHandler = nil
                    stderr.fileHandleForReading.readabilityHandler = nil
                    if finished.terminationStatus == 0 {
                        continuation.resume()
                    } else if finished.terminationStatus == 15 || finished.terminationReason == .uncaughtSignal {
                        continuation.resume(throwing: InstaDownloadError.cancelled)
                    } else {
                        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        let message = err.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(
                            throwing: InstaDownloadError.ytDlpFailed(message.isEmpty ? "Código \(finished.terminationStatus)." : message)
                        )
                    }
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: InstaDownloadError.ytDlpFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw InstaDownloadError.ytDlpFailed("No se generó el archivo de vídeo.")
        }
        progress(1)
    }

    static func parseProgress(_ text: String) -> Double? {
        let pattern = #"\[download\]\s+(\d+(?:\.\d+)?)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let capture = Range(match.range(at: 1), in: text),
              let value = Double(text[capture]) else {
            return nil
        }
        return min(1, max(0, value / 100))
    }

    private func mergedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]
        let path = env["PATH"] ?? ""
        env["PATH"] = (extra + [path]).joined(separator: ":")
        return env
    }
}
