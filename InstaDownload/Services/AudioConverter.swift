import Foundation

struct AudioConverter: Sendable {
    static func convertToMP3(
        source: URL,
        destination: URL,
        ffmpegURL: URL? = FFmpegLocator.locate()
    ) async throws {
        guard let ffmpegURL else {
            throw InstaDownloadError.ffmpegMissing
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-nostats",
            "-loglevel", "error",
            "-y",
            "-i", source.path,
            "-vn",
            "-c:a", "libmp3lame",
            "-q:a", "2",
            destination.path
        ]

        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]
        let path = env["PATH"] ?? ""
        env["PATH"] = (extra + [path]).joined(separator: ":")
        process.environment = env

        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: InstaDownloadError.cancelled)
                    return
                }

                process.terminationHandler = { finished in
                    if finished.terminationStatus == 0 {
                        continuation.resume()
                    } else if finished.terminationStatus == 15 || finished.terminationReason == .uncaughtSignal {
                        continuation.resume(throwing: InstaDownloadError.cancelled)
                    } else {
                        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        let message = err.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(
                            throwing: InstaDownloadError.conversionFailed(message.isEmpty ? "Código \(finished.terminationStatus)." : message)
                        )
                    }
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: InstaDownloadError.conversionFailed(error.localizedDescription))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw InstaDownloadError.conversionFailed("No se generó el archivo de audio.")
        }
    }
}
