import Foundation

@MainActor
final class FileDownloader {
    private var runtime: Runtime?

    func download(
        from remote: URL,
        to destination: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL {
        let runtime = Runtime()
        self.runtime = runtime
        defer { self.runtime = nil }
        return try await runtime.run(from: remote, to: destination, progress: progress)
    }

    func cancel() {
        runtime?.cancel()
    }
}

private final class Runtime: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var destination: URL?
    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@MainActor (Double) -> Void)?
    private let lock = NSLock()

    func run(
        from remote: URL,
        to destination: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL {
        self.destination = destination
        self.progressHandler = progress
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 30
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let request = InstagramRequest.media(remote)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let downloadTask = self.session?.downloadTask(with: request)
                self.task = downloadTask
                downloadTask?.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
        finish(.failure(InstaDownloadError.cancelled))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        let handler = progressHandler
        Task { @MainActor in
            handler?(fraction)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            finish(.failure(InstaDownloadError.network("El servidor respondió \(http.statusCode) al descargar el archivo.")))
            return
        }
        guard let destination else {
            finish(.failure(InstaDownloadError.saveFailed("No hay carpeta de destino.")))
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(InstaDownloadError.saveFailed(error.localizedDescription)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            if (error as? URLError)?.code == .cancelled {
                finish(.failure(InstaDownloadError.cancelled))
            } else {
                finish(.failure(InstaDownloadError.network(error.localizedDescription)))
            }
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        session?.finishTasksAndInvalidate()
        continuation?.resume(with: result)
    }
}
