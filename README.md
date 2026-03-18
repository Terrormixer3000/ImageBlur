# ImageBlur

Native macOS-App zum selektiven Verpixeln von Bildausschnitten. Die App lädt ein Bild, erlaubt mehrere nicht-destruktive Verpixelungsbereiche und exportiert eine neue Datei im Originalformat mit unveränderten Pixelabmessungen.

## Features
- Bild öffnen per Dialog oder Drag-and-drop
- Export als Kopie im Originalformat
- Mehrere Verpixelungsbereiche pro Bild
- Formen:
  - Rechteck
  - Ellipse
  - Lasso
- Regionen verschieben, skalieren, drehen und löschen
- Einstellbare Pixelationsstärke pro Region
- Zoom und Pan im Editor
- Undo/Redo für zentrale Bearbeitungsschritte

## Anforderungen
- macOS 14 oder neuer
- Xcode 26.3 oder neuer
- Swift 6.2 oder neuer

## Build und Start
```bash
swift build
swift run
```

## Bedienung
1. App starten.
2. Ein Bild über `Öffnen` laden oder in das Fenster ziehen.
3. Werkzeug auswählen:
   - `Auswählen`
   - `Rechteck`
   - `Ellipse`
   - `Lasso`
4. Einen oder mehrere Bereiche auf dem Bild anlegen.
5. Im Auswahlmodus Regionen verschieben, skalieren oder über den orangefarbenen Griff drehen.
6. Pixelationsstärke über Toolbar oder Inspector anpassen.
7. Mit `Speichern als Kopie` das bearbeitete Bild exportieren.

## Unterstützte Formate
- PNG
- JPEG / JPG
- TIFF
- HEIC, sofern systemseitig verfügbar

## Technische Details
- UI: `SwiftUI`
- Bildverarbeitung: `Core Image`
- Dateiverarbeitung: `CGImageSource` / `CGImageDestination`
- Interne Regionsgeometrie in Bildkoordinaten

Die Pixelmaße des Bildes bleiben beim Export erhalten. Das Dateiformat bleibt ebenfalls erhalten. Bei JPEG wird das Bild neu kodiert, daher ist die Datei nicht byte-identisch, aber weiterhin im JPEG-Format.

## Projektstruktur
```text
Sources/ImageBlur/
├── ImageBlurApp.swift
├── Models/
├── Services/
├── ViewModel/
└── Views/
```

## Aktueller Stand und Grenzen
- Lasso ist frei anlegbar und als Ganzes transformierbar.
- Punktweise Nachbearbeitung von Lasso-Knoten ist noch nicht implementiert.
- Winkelraster beim Drehen ist noch nicht implementiert.
- Kein Batch-Export in der aktuellen Version.

## Entwicklung
Für Arbeitsregeln und Projektkonventionen siehe [AGENTS.md](/Users/marioheusser/Repositorys/vibing/image_blur/AGENTS.md).
