# Ámbito: descarga_audio_mp3

> **Regla de oro:** Este documento es la verdad técnica de este módulo. Cualquier agente asignado a este ámbito debe leerlo antes de inspeccionar o editar archivos. Al finalizar una tarea, si se descubre una peculiaridad o cambia el terreno, este documento debe actualizarse en la misma sesión.

---

## 1. Estado Actual

- **Objetivo del ámbito:** Permitir la selección del formato de descarga (Vídeo MP4 o Audio MP3) para publicaciones públicas de Instagram, YouTube y X, gestionando la extracción y codificación a MP3 mediante `ffmpeg` y `yt-dlp` según la plataforma y motor disponible.
- **Fase:** Estable (implementación, integración UI, maqueta y suite de tests finalizadas).
- **Funcionalidades completadas:**
  - [x] Descarga de vídeo MP4 nativo (Instagram).
  - [x] Descarga de vídeo MP4 con muxing de mejor calidad vía yt-dlp y ffmpeg (YouTube y X).
  - [x] Detección de binarios de entorno (`yt-dlp` y `ffmpeg`) en rutas estándar.
  - [x] Maqueta viva con estados validados y auditada por `ui_reviewer` según Apple HIG.
  - [x] Implementación de `DownloadFormat` (`.mp4`, `.mp3`).
  - [x] Segmented Picker en `ContentView.swift` con accesibilidad y adaptabilidad HIG.
  - [x] Extracción y conversión a MP3 en `YTDlpEngine` (`-x --audio-format mp3`).
  - [x] Conversión a MP3 para descargas nativas de Instagram usando `ffmpeg` local (`AudioConverter`).
  - [x] Prevención activa y mensajes contextuales si falta `ffmpeg`.
  - [x] Tests unitarios del modelo de formato, nombrado de archivos (`.mp3`), errores y comportamiento del ViewModel.
- **Pendiente / Roadmap inmediato:**
  - [ ] Ninguno para este ticket.
- **Deuda técnica conocida:**
  - macOS no incluye codificador nativo de MP3 en AVFoundation (solo AAC / ALAC / PCM); por tanto, la generación de MP3 depende indispensablemente del binario `ffmpeg`.

---

## 2. Terreno de Juego (Ficheros y Límites)

> **Límite operativo:** El agente asignado a este ámbito solo tiene autorización para editar los archivos listados abajo. Si requiere modificar código fuera de su terreno, debe detenerse y pedir autorización al Supervisor.

### Archivos bajo propiedad de este ámbito:
- `InstaDownload/Domain/DownloadFormat.swift` (nuevo)
- `InstaDownload/Domain/ResolvedMedia.swift`
- `InstaDownload/Domain/FilenameSanitizer.swift`
- `InstaDownload/Domain/InstaDownloadError.swift`
- `InstaDownload/Services/YTDlpEngine.swift`
- `InstaDownload/Services/AudioConverter.swift` (nuevo o integrado en servicios)
- `InstaDownload/UI/DownloadViewModel.swift`
- `InstaDownload/UI/ContentView.swift`
- `InstaDownloadTests/DownloadFormatTests.swift` (nuevo)
- `InstaDownloadTests/FilenameSanitizerTests.swift`
- `InstaDownloadTests/YTDlpEngineTests.swift`
- `docs/ambitos/descarga_audio_mp3.md`
- `mockup/index.html`

### Dependencias externas permitidas (solo lectura):
- `InstaDownload/Services/HTTPClient.swift`
- `InstaDownload/Services/DestinationStore.swift`
- `InstaDownload/Domain/URLParsing.swift`
- `InstaDownload/Domain/MediaLink.swift`

---

## 3. Modelo de Datos y Dominio del Ámbito

- **Entidades principales:**
  - `DownloadFormat`: Enum `[mp4, mp3]` con propiedades `id`, `label`, `systemImage`, `fileExtension`.
  - `ResolvedMedia`: Enriquecido para generar `suggestedFilename(for: DownloadFormat)` o pasar el formato requerido al descargador.
  - `DownloadViewModel`: Expone `var selectedFormat: DownloadFormat = .mp4`, condiciona `canDownload` si `selectedFormat == .mp3 && !ffmpegAvailable`.
- **Máquina de estados:**
  - Fases de descarga: `idle` -> `resolving` -> `ready(ResolvedMedia)` -> `downloading(Double)` -> `finished(URL)` | `failed(String)`.
  - En fase `downloading` para MP3:
    - En motor `ytDlp`: invocación de `yt-dlp` con `-x --audio-format mp3`.
    - En motor `native`: descarga directa del recurso MP4 seguida de conversión local `ffmpeg -i temp.mp4 -vn -c:a libmp3lame -q:a 2 final.mp3` y purga del temporal.
- **Invariantes y reglas de negocio:**
  - El formato por defecto siempre es `mp4` para preservar el comportamiento histórico de la app.
  - La alternancia de formato no debe disparar una re-resolución de la URL si el contenido ya fue resuelto (`lastMedia` o `ready`).
  - No se permite iniciar descarga MP3 si `ffmpegAvailable == false`. La interfaz debe deshabilitar el botón y mostrar el mensaje instructivo (`brew install ffmpeg`).

---

## 4. Trampas Encontradas (Gotchas y Lecciones Aprendidas)

- ⚠️ **[Gotcha 1]:** `yt-dlp` con `-x --audio-format mp3 -o dest.mp3` descarga primero un archivo temporal con la extensión nativa del flujo de audio (`.webm`, `.m4a` o `.part`) y luego invoca `ffmpeg` para extraerlo y guardarlo exactamente como `.mp3`. Si se especifica `-o "dest.%(ext)s"`, el archivo final terminará en `.mp3`. Si se especifica `-o "dest.mp3"`, yt-dlp también lo gestiona correctamente pero requiere que `ffmpeg` esté en el PATH o referenciado vía `--ffmpeg-location`.
- ⚠️ **[Gotcha 2]:** En macOS no existe encoder nativo de MP3 a través de `AVAssetExportSession` (Apple soporta `.m4a` pero no `.mp3`). Para Instagram nativo es imprescindible contar con `ffmpeg` si se desea entregar formato `.mp3` genuino.
- ⚠️ **[Gotcha 3]:** En `ContentView.swift`, un `Picker` segmentado con `ForEach` requiere `.tag(format)` para que el enlace bidireccional `@Bindable` funcione correctamente en macOS Sonoma/Sequoia.
