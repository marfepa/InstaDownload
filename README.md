# InstaDownload

App nativa de macOS (SwiftUI) para guardar en el Mac el vídeo de una publicación **pública** de Instagram, YouTube o X.

Uso personal. No inicia sesión, no descarga stories ni cuentas privadas y no recorre perfiles, canales ni playlists.

## Qué hace

1. Pegas la URL de un post/reel de Instagram, un vídeo/short de YouTube o un post de X con vídeo.
2. La app muestra una vista previa (autor y miniatura cuando el sitio la expone).
3. Eliges el formato deseado: **Vídeo (MP4)** o **Audio (MP3)**.
4. El archivo se guarda en la carpeta que elijas (por defecto Descargas).

Instagram intenta primero un extractor nativo (con conversión a MP3 vía `ffmpeg` si se solicita audio). YouTube y X van siempre por `yt-dlp`.

## Requisitos

- macOS 14 o posterior
- Xcode 15+ (en este Mac, Xcode 27)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) (imprescindible para YouTube y X; también es el respaldo de Instagram)

```bash
brew install yt-dlp
```

Para fusionar vídeo y audio de YouTube con mejor calidad:

```bash
brew install ffmpeg
```

La app busca `yt-dlp` y `ffmpeg` en `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin` y `~/.local/bin`. Sin `ffmpeg`, YouTube se descarga en un formato ya muxed (a menudo menor calidad).

## Desarrollo

```bash
cd /Users/mariofernandez/Projects/InstaDownload
xcodegen generate
xcodebuild -project InstaDownload.xcodeproj -scheme InstaDownload -destination 'platform=macOS' build
xcodebuild -project InstaDownload.xcodeproj -scheme InstaDownload -destination 'platform=macOS' test
open InstaDownload.xcodeproj
```

## Límites

- Instagram: posts, reels, IGTV y enlaces de compartir que redirijan a esos (`/p/`, `/reel/`, `/tv/`).
- YouTube: `watch`, `youtu.be`, `shorts` y `embed` de un vídeo. No playlists, canales ni lives en curso.
- X: `x.com/{user}/status/{id}` y equivalentes de Twitter. No perfiles ni Spaces.
- El contenido pertenece a quien lo publicó; respeta sus derechos.
- No hay distribución App Store ni sandbox de Mac App Store en esta versión.
