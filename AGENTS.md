# AGENTS

## Projektüberblick
- `ImageBlur` ist eine native macOS-App in `SwiftUI`.
- Ziel ist das nicht-destruktive Verpixeln von Bildausschnitten bei unveränderten Pixelabmessungen.
- Unterstützte Formen im aktuellen Stand:
  - Rechteck
  - Ellipse
  - Lasso
- Regionen können angelegt, ausgewählt, verschoben, skaliert, gedreht und gelöscht werden.
- Beim Öffnen eines neuen Bildes mit ungespeicherten Änderungen muss eine Verwerfen-/Speichern-Abfrage erscheinen.

## Technischer Stack
- `Swift 6`
- `Swift Package Manager`
- `SwiftUI` für die App und den Editor
- `Core Image` für die Pixelation
- `ImageIO` für Laden und Export im Originalformat

## Projektstruktur
```text
Package.swift
Sources/ImageBlur/
├── ImageBlurApp.swift
├── Models/
│   ├── BlurRegion.swift
│   └── ImageDocument.swift
├── Services/
│   ├── BlurRenderer.swift
│   └── ImageIOService.swift
├── ViewModel/
│   └── EditorViewModel.swift
└── Views/
    ├── ContentView.swift
    └── EditorCanvasView.swift
```

## Architekturregeln
- Regionen werden immer in Bildkoordinaten gespeichert, nicht in View-Koordinaten.
- Vorschau und Export sollen dieselbe Renderlogik verwenden.
- Änderungen an Bildformat, Pixelabmessungen und Seitenverhältnis sind nicht erlaubt.
- Export erfolgt als neue Datei im Eingabeformat.
- Neue Bearbeitungsfunktionen sollen Undo/Redo unterstützen.
- Bildwechsel darf bestehende Änderungen niemals stillschweigend verwerfen.

## Arbeitsregeln
- Vor Änderungen zuerst `swift build` ausführen, wenn ein technischer Stand abgeglichen werden muss.
- Bei Rendering-Änderungen immer sowohl Preview als auch Export prüfen.
- Interaktionslogik im Canvas möglichst in kleine, nachvollziehbare Zustände halten.
- Keine unnötigen Drittanbieter-Abhängigkeiten einführen.
- Bestehende Nutzerfunktionen nicht stillschweigend vereinfachen oder entfernen.
- Lokale Editor-Dateien wie `.vscode/` nicht committen.

## Bekannte Grenzen im aktuellen Stand
- Lasso kann als Form erstellt, transformiert und gedreht werden, aber noch nicht punktweise editiert werden.
- Winkelraster beim Drehen ist noch nicht umgesetzt.
- Die App ist aktuell ein Einzelbild-Editor ohne Batch-Verarbeitung.

## Verifikation
- Build:
  - `swift build`
- Start:
  - `swift run`

## Typische nächste Aufgaben
- Punktbearbeitung für Lasso-Formen
- Winkelraster mit `Shift`
- Bessere Performance bei sehr großen Bildern
- Zusätzliche Dateitypen und robustere Metadatenübernahme
