# Floating Camera 1.1.0

A lightweight, native macOS menu bar app that keeps your camera floating above everything else. No Dock icon, no Electron, no account, no analytics.

## What's new in 1.1.0

- **Vertical Rectangle** shape (9:16): crops the sides of the camera image, ideal for vertical video. Supports the **Rounding** slider.

![Floating Camera shapes](https://raw.githubusercontent.com/neo22s/floating-cam/master/assets/shapes.png)

## Download and install

1. Download **FloatingCamera.zip** from the Assets section below.
2. Unzip it and drag **FloatingCamera.app** to `/Applications`.
3. Open the app and allow camera access when macOS asks.

Requires **macOS 14 or later** and a camera (built-in, external, Continuity Camera, or Desk View).

This build is **ad-hoc signed**, so Gatekeeper may warn on first launch. Right-click the app and choose **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/FloatingCamera.app
```

## How to use it

The aperture icon appears in the menu bar. Click it to open the menu.

- **Camera** — choose the active camera.
- **Shape** — Circle, Rounded Square, Rectangle, Vertical Rectangle, Square, Heart, Star, Hexagon, Pentagon, Diamond or Capsule.
- **Border** — width and color.
- **Size** — resize from 160 to 800 pt. The shape keeps its aspect ratio.
- **Opacity** — 10–100%.
- **Rounding** — rounds Rectangle, Vertical Rectangle, Rounded Square and Square. It only appears for those shapes.
- **Zoom** — crop the image inside the shape from 100% to 300%.
- **Advanced** — resolution (480p/720p/1080p), frame rate (15/24/30/60 fps), mirror, always on top, reset position, check for updates and language.
- **Hide Camera** — hides the overlay and stops the capture session. Use `⌃⌥H` from anywhere.
- **Quit** — quits the app.

Drag anywhere inside the overlay to move it. **Reset Position** centers it on the current screen. Right-click the overlay (or use a two-finger tap) for **Hide Camera**, **Reset Position** and **Quit Floating Camera**.

The UI follows macOS by default. You can force **English** or **Español** in **Advanced → Language**.

## Updates

The app checks this GitHub Releases feed once every 30 days at launch. You can also use **Advanced → Check for Updates…**. When a newer version exists it downloads, verifies and installs the update, then relaunches.

Because the app is ad-hoc signed, macOS may ask for camera permission again after an update.

## Privacy and performance

- The camera preview is hardware-accelerated by AVFoundation.
- Hiding the camera stops the capture session completely: 0% camera CPU while hidden.
- No analytics, telemetry, or account. The only network request is the update check.
- Resolution and frame rate mainly affect camera bandwidth, heat and image quality. The app's CPU stays low because it does no per-frame filtering.

## Build from source

```bash
git clone https://github.com/neo22s/floating-cam.git
cd floating-cam
./build.sh --universal
./test.sh
```

## License

MIT. Based on the original Floating Camera by Tomás Menezes (@tomasmenezes), also MIT.

---

# Floating Camera 1.1.0 — Español

Una utilidad nativa y ligera para macOS que mantiene tu cámara flotando sobre todo lo demás. Sin icono en el Dock, sin Electron, sin cuenta y sin analíticas.

## Novedades de 1.1.0

- Nueva forma **Rectángulo vertical** (9:16): recorta los laterales de la imagen, ideal para vídeo vertical. Admite el slider de **Redondeo**.

## Descargar e instalar

1. Descarga **FloatingCamera.zip** desde la sección de Assets.
2. Descomprímelo y arrastra **FloatingCamera.app** a `/Applications`.
3. Abre la app y permite el acceso a la cámara cuando macOS lo pida.

Requiere **macOS 14 o posterior** y una cámara (integrada, externa, Continuity Camera o Desk View).

El build está firmado en modo **ad-hoc**, así que Gatekeeper puede avisar la primera vez. Haz clic derecho en la app → **Abrir**, o ejecuta:

```bash
xattr -dr com.apple.quarantine /Applications/FloatingCamera.app
```

## Cómo usarla

Haz clic en el icono de apertura de la barra de menús.

- **Cámara** — elige la cámara activa.
- **Forma** — Círculo, Cuadrado redondeado, Rectángulo, Rectángulo vertical, Cuadrado, Corazón, Estrella, Hexágono, Pentágono, Diamante o Cápsula.
- **Borde** — grosor y color.
- **Tamaño** — de 160 a 800 pt. La forma mantiene su proporción.
- **Opacidad** — de 10% a 100%.
- **Redondeo** — redondea Rectángulo, Rectángulo vertical, Cuadrado redondeado y Cuadrado. Solo aparece con esas formas.
- **Zoom** — recorta la imagen dentro de la forma, de 100% a 300%.
- **Avanzado** — resolución (480p/720p/1080p), FPS (15/24/30/60), espejo, siempre encima, restablecer posición, buscar actualizaciones e idioma.
- **Ocultar cámara** — oculta el overlay y detiene la captura. Atajo global: `⌃⌥H`.
- **Salir** — cierra la app.

Arrastra dentro del overlay para moverlo. **Restablecer posición** lo centra en la pantalla actual. Haz clic derecho sobre el overlay (o toca con dos dedos) para **Ocultar cámara**, **Restablecer posición** y **Salir de Floating Camera**.

El idioma sigue a macOS por defecto. Puedes forzar **English** o **Español** en **Avanzado → Idioma**.

## Actualizaciones

La app consulta este feed de GitHub Releases una vez cada 30 días al arrancar. También puedes usar **Avanzado → Buscar actualizaciones…**. Si hay una versión nueva, la descarga, la verifica, la instala y se reinicia.

Como la firma es ad-hoc, macOS puede volver a pedir permiso de cámara después de una actualización.

## Privacidad y rendimiento

- La preview usa AVFoundation acelerado por hardware.
- Al ocultar la cámara se detiene la sesión de captura: 0% de CPU de cámara.
- Sin analíticas, telemetría ni cuentas. La única petición de red es la búsqueda de actualizaciones.
- La resolución y los FPS afectan sobre todo a ancho de banda, calor y calidad; el CPU de la app se mantiene bajo porque no procesa frames.

## Licencia

MIT. Basado en el proyecto original Floating Camera de Tomás Menezes (@tomasmenezes), también MIT.
