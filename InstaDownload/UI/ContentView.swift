import SwiftUI

struct ContentView: View {
    @Bindable var model: DownloadViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            header
            urlBlock
            previewBlock
            destinationBlock
            actionBlock
            statusBlock
        }
        .padding(32)
        .frame(width: 480)
        .onAppear {
            model.consumeClipboardIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("InstaDownload", systemImage: "arrow.down.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Pega un enlace público de Instagram y guarda el vídeo en tu Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var urlBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enlace")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("https://www.instagram.com/reel/…", text: $model.urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.resolveNow()
                    }
                    .onChange(of: model.urlText) {
                        model.urlDidChange()
                    }
                Button("Pegar") {
                    model.pasteFromClipboard()
                }
                .disabled(model.isBusy)
            }
        }
    }

    @ViewBuilder
    private var previewBlock: some View {
        if let media = model.currentMedia {
            HStack(alignment: .top, spacing: 16) {
                thumbnail(media.thumbnailURL)
                VStack(alignment: .leading, spacing: 6) {
                    Text(media.authorName.map { "@\($0)" } ?? media.source.displayKind)
                        .font(.headline)
                        .lineLimit(1)
                    Text(previewSubtitle(media))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let title = media.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func previewSubtitle(_ media: ResolvedMedia) -> String {
        var parts = [media.source.displayKind]
        if let code = media.source.shortcode {
            parts.append(code)
        }
        if media.engine == .ytDlp {
            parts.append("yt-dlp")
        }
        return parts.joined(separator: " · ")
    }

    private func thumbnail(_ url: URL?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Image(systemName: "play.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "play.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var destinationBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guardar en")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(model.destinationDisplay)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(model.destination.path)
                Spacer(minLength: 8)
                Button("Cambiar…") {
                    model.chooseFolder()
                }
                .disabled(model.isBusy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var actionBlock: some View {
        VStack(spacing: 12) {
            Button {
                model.download()
            } label: {
                Text("Descargar")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canDownload)

            if case .downloading = model.phase {
                Button("Cancelar", role: .cancel) {
                    model.cancelDownload()
                }
                .controlSize(.regular)
            }
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch model.phase {
        case .idle:
            Text(model.ytDlpAvailable
                 ? "Uso personal · solo publicaciones públicas"
                 : "Uso personal · para más fiabilidad: brew install yt-dlp")
                .font(.caption)
                .foregroundStyle(.tertiary)
        case .resolving:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Obteniendo datos del vídeo…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .ready(let media):
            Text(media.engine == .ytDlp
                 ? "Listo para descargar con yt-dlp."
                 : "Vídeo encontrado. Pulsa Descargar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .downloading(let fraction):
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: fraction)
                Text(fraction > 0 ? "Descargando \(Int(fraction * 100))%" : "Descargando…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        case .finished(let url):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Mostrar en Finder") {
                    model.revealInFinder(url)
                }
            }
            .font(.subheadline)
        case .failed(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ContentView(model: DownloadViewModel())
}
