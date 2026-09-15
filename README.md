# InstaDownload

App nativa de macOS (SwiftUI) para guardar en el Mac el vídeo de una publicación **pública** de Instagram.

Uso personal. No inicia sesión, no descarga stories ni cuentas privadas y no recorre perfiles enteros.

## Qué hace

1. Pegas la URL de un post, reel o IGTV público.
2. La app muestra una vista previa (autor y miniatura cuando Instagram la expone).
3. El MP4 se guarda en la carpeta que elijas (por defecto Descargas).

## Requisitos

- macOS 14 o posterior
- Xcode 15+ (en este Mac, Xcode 27)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Instagram ya no expone de forma estable la URL MP4 en el HTML público. El extractor nativo se intenta primero; en la práctica casi siempre hace falta:

```bash
brew install yt-dlp
```

La app usará `yt-dlp` si está en `/opt/homebrew/bin` o `/usr/local/bin`.

## Desarrollo

```bash
cd /Users/mariofernandez/Projects/InstaDownload
xcodegen generate
xcodebuild -project InstaDownload.xcodeproj -scheme InstaDownload -destination 'platform=macOS' build
xcodebuild -project InstaDownload.xcodeproj -scheme InstaDownload -destination 'platform=macOS' test
open InstaDownload.xcodeproj
```

## Límites

- Solo enlaces públicos (`/p/`, `/reel/`, `/tv/` y enlaces de compartir que redirijan a esos).
- El contenido pertenece a quien lo publicó; respeta sus derechos.
- No hay distribución App Store ni sandbox de Mac App Store en esta versión.
