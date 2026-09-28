import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DownloadViewModel {
    enum Phase: Equatable {
        case idle
        case resolving
        case ready(ResolvedMedia)
        case downloading(Double)
        case finished(URL)
        case failed(String)
    }

    var urlText: String = ""
    var destination: URL
    var selectedFormat: DownloadFormat = .mp4
    var phase: Phase = .idle
    var ytDlpAvailable: Bool
    var ffmpegAvailable: Bool
    private(set) var lastMedia: ResolvedMedia?

    private var resolveTask: Task<Void, Never>?
    private var workTask: Task<Void, Never>?
    private let downloader = FileDownloader()
    private let resolver: MediaResolver

    init(
        destination: URL = DestinationStore.load(),
        selectedFormat: DownloadFormat = .mp4,
        ytDlpAvailable: Bool = YTDlpEngine.locate() != nil,
        ffmpegAvailable: Bool = FFmpegLocator.locate() != nil,
        resolver: MediaResolver? = nil
    ) {
        self.destination = destination
        self.selectedFormat = selectedFormat
        self.ytDlpAvailable = ytDlpAvailable
        self.ffmpegAvailable = ffmpegAvailable
        self.resolver = resolver ?? MediaResolver(ytDlpAvailable: ytDlpAvailable)
    }

    var destinationDisplay: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = destination.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    var currentMedia: ResolvedMedia? {
        switch phase {
        case .ready(let media):
            return media
        case .downloading, .finished:
            return lastMedia
        default:
            return lastMedia
        }
    }

    var canDownload: Bool {
        guard currentMedia != nil, !isBusy else { return false }
        if selectedFormat == .mp3 && !ffmpegAvailable {
            return false
        }
        return true
    }

    var isBusy: Bool {
        switch phase {
        case .resolving, .downloading:
            return true
        default:
            return false
        }
    }

    func consumeClipboardIfNeeded() {
        guard urlText.isEmpty else { return }
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MediaLink.looksSupported(trimmed) else { return }
        urlText = trimmed
    }

    func pasteFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        urlText = string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func urlDidChange() {
        resolveTask?.cancel()
        lastMedia = nil
        switch phase {
        case .downloading:
            break
        default:
            phase = .idle
        }
        guard MediaLink.looksSupported(urlText) else { return }
        resolveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.resolveNow()
        }
    }

    func resolveNow() {
        resolveTask?.cancel()
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            phase = .failed(InstaDownloadError.invalidURL.localizedDescription)
            return
        }
        phase = .resolving
        workTask?.cancel()
        workTask = Task { [weak self] in
            guard let self else { return }
            do {
                let media = try await self.resolver.resolve(raw)
                guard !Task.isCancelled else { return }
                self.lastMedia = media
                self.phase = .ready(media)
            } catch is CancellationError {
                return
            } catch let error as InstaDownloadError {
                guard !Task.isCancelled else { return }
                self.phase = .failed(error.localizedDescription)
            } catch {
                guard !Task.isCancelled else { return }
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seleccionar"
        panel.message = "Carpeta donde guardar el vídeo"
        panel.directoryURL = destination
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destination = url
        DestinationStore.save(url)
    }

    func download() {
        guard let media = currentMedia else { return }
        workTask?.cancel()
        workTask = Task { [weak self] in
            guard let self else { return }
            self.phase = .downloading(0)
            let dest = FilenameSanitizer.uniqueURL(
                in: self.destination,
                preferredName: media.suggestedFilename(for: self.selectedFormat)
            )
            do {
                let file: URL
                if let videoURL = media.videoURL, media.engine == .native {
                    do {
                        if self.selectedFormat == .mp3 {
                            let tempDest = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString + ".mp4")
                            defer {
                                try? FileManager.default.removeItem(at: tempDest)
                            }
                            _ = try await self.downloader.download(from: videoURL, to: tempDest) { [weak self] fraction in
                                self?.phase = .downloading(fraction * 0.8)
                            }
                            try await AudioConverter.convertToMP3(
                                source: tempDest,
                                destination: dest,
                                ffmpegURL: self.ffmpegAvailable ? FFmpegLocator.locate() : nil
                            )
                            self.phase = .downloading(1.0)
                            file = dest
                        } else {
                            file = try await self.downloader.download(from: videoURL, to: dest) { [weak self] fraction in
                                self?.phase = .downloading(fraction)
                            }
                        }
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch let error as InstaDownloadError where error == .cancelled {
                        throw error
                    } catch {
                        file = try await self.downloadWithYTDlp(from: media.source.pageURL, to: dest, fallingBackFrom: error)
                    }
                } else {
                    file = try await self.downloadWithYTDlp(from: media.source.pageURL, to: dest, fallingBackFrom: nil)
                }
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: dest)
                    self.restoreAfterCancel()
                    return
                }
                self.phase = .finished(file)
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: dest)
                self.restoreAfterCancel()
            } catch let error as InstaDownloadError where error == .cancelled {
                try? FileManager.default.removeItem(at: dest)
                self.restoreAfterCancel()
            } catch let error as InstaDownloadError {
                try? FileManager.default.removeItem(at: dest)
                self.phase = .failed(error.localizedDescription)
            } catch {
                try? FileManager.default.removeItem(at: dest)
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelDownload() {
        workTask?.cancel()
        downloader.cancel()
        restoreAfterCancel()
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func downloadWithYTDlp(from url: URL, to dest: URL, fallingBackFrom previous: Error?) async throws -> URL {
        guard let engine = YTDlpEngine() else {
            if let previous { throw previous }
            throw InstaDownloadError.ytDlpMissing
        }
        try await engine.download(
            pageURL: url,
            to: dest,
            ffmpegURL: ffmpegAvailable ? FFmpegLocator.locate() : nil,
            format: selectedFormat
        ) { fraction in
            Task { @MainActor [weak self] in
                self?.phase = .downloading(fraction)
            }
        }
        return dest
    }

    private func restoreAfterCancel() {
        if let lastMedia {
            phase = .ready(lastMedia)
        } else {
            phase = .idle
        }
    }
}
