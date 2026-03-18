# ImageBlur

ImageBlur is an open source macOS app for selectively pixelating parts of an image without changing the original image dimensions. It is built natively with SwiftUI, keeps editing non-destructive until export, and is designed for quick redaction workflows on screenshots, photos, and other static images.

Copyright (C) 2026 Terrormixer3000.

## AI Disclaimer
Parts of this project were created or refined with the help of AI-assisted development tools. All generated output should be treated as human-reviewed project code and documentation, not as an authoritative source on its own.

## Features
- Open images via file dialog, app open events, or drag and drop
- Export a new copy in the original file format
- Optional Sparkle-based update checks for packaged `.app` releases
- Confirmation dialog before replacing an image with unsaved changes
- Multiple pixelation regions per image
- Supported shapes:
  - Rectangle
  - Ellipse
  - Lasso
- Move, resize, rotate, and delete regions
- Delete regions directly in the canvas via the red `x` handle or from the region list
- Adjustable pixelation strength per region
- Zoom and pan in the editor, with zoom focused on the mouse position
- Undo/redo for the main editing actions

## Screenshots
Screenshots and short workflow GIFs are planned, but not included yet.

## Requirements
- macOS 14 or newer
- Xcode 26.3 or newer
- Swift 6.2 or newer

## Installation
### Download from GitHub Releases
Tagged releases publish an unsigned macOS `.app.zip` artifact.

1. Download the latest `ImageBlur-<version>-macos.zip` asset from the Releases page.
2. Unzip the archive.
3. Move `ImageBlur.app` to `/Applications` if desired.
4. On first launch, macOS may show the usual warning for an unsigned app. Use `Open` from Finder's context menu if needed.

### Build from source
```bash
swift build
swift run
```

### Create a local distributable app bundle
```bash
swift build -c release
./scripts/assemble_app.sh release
```

### Create a local release zip
```bash
./scripts/build_release.sh v0.1.0
```

This produces a zip archive in `dist/` that matches the format used by GitHub Releases.

## Sparkle Updates
ImageBlur includes optional Sparkle integration for packaged `.app` builds.

To enable real update checks in release artifacts, provide both of these at build time:
- `SPARKLE_APPCAST_URL`
- `SPARKLE_PUBLIC_ED_KEY`

Example:
```bash
export SPARKLE_APPCAST_URL="https://example.com/imageblur/appcast.xml"
export SPARKLE_PUBLIC_ED_KEY="your-public-ed25519-key"
./scripts/build_release.sh v0.1.0
```

Without both values, Sparkle stays disabled and the app runs normally.

For a production Sparkle setup you still need:
- a hosted appcast served over HTTPS
- update archives signed with Sparkle's EdDSA tooling
- a release process that publishes both the archive and the appcast

In this repository, the release workflow is set up to publish `appcast.xml` to a dedicated `appcast` branch instead of committing release metadata back to `main`.

## Usage
1. Launch the app.
2. Open an image with `Open` or drag it into the window.
3. Choose a tool:
   - `Select`
   - `Rectangle`
   - `Ellipse`
   - `Lasso`
4. Create one or more regions on the image.
5. In select mode, move, resize, or rotate a region using the orange rotation handle.
6. Delete regions using the red `x` handle or the trash button in the region list.
7. Adjust pixelation strength with the toolbar slider.
8. Export the edited image with `Save Copy`.
9. If unsaved changes exist and you open another image, the app asks whether to save, discard, or cancel.

## Supported Formats
- PNG
- JPEG / JPG
- TIFF
- HEIC, when supported by the system

## Technical Notes
- UI: `SwiftUI`
- Image processing: `Core Image`
- File import/export: `CGImageSource` / `CGImageDestination`
- Region geometry is stored in image coordinates

The exported image keeps the original pixel dimensions and file format. JPEG output is re-encoded, so it is not byte-identical to the source file, but it remains a JPEG file.

## Project Structure
```text
Sources/ImageBlur/
├── ImageBlurApp.swift
├── Models/
├── Services/
├── ViewModel/
└── Views/
```

## Current Limitations
- Lasso shapes can be created and transformed as a whole, but their points cannot be edited individually yet.
- Angle snapping while rotating is not implemented yet.
- The app is currently a single-image editor without batch export.

## Contributing
Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) for the local workflow and contribution expectations.

For engineering conventions and repo-specific implementation notes, see [AGENTS.md](AGENTS.md).

## Security
For vulnerability reporting guidance, see [SECURITY.md](SECURITY.md).

## License
This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.
