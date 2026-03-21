# ImageBlur

ImageBlur is an open source macOS app for selectively pixelating image regions without changing the original image dimensions or output format. Editing stays non-destructive until export.

Copyright (C) 2026 Terrormixer3000.

## Features
- Open images via file dialog or drag and drop
- Add multiple pixelation regions per image
- Rectangle, ellipse, and lasso tools
- Move, resize, rotate, and delete regions
- Adjustable pixelation strength
- Export a new copy in the original file format
- Undo/redo for core editing actions
- Optional Sparkle-based update checks in packaged releases

## Requirements
- macOS 14 or newer
- Xcode 26.3 or newer
- Swift 6.2 or newer

## Installation
1. Download the latest `ImageBlur-<version>-macos.zip` asset from the Releases page.
2. Unzip the archive.
3. Move `ImageBlur.app` to `/Applications`.
4. On first launch, macOS may show the usual warning for an unsigned app. Use `Open` from Finder's context menu if needed.

## Build From Source
```bash
swift build
swift run
```

## Build A Release Archive
```bash
./scripts/build_release.sh v0.1.0
```

This creates a release ZIP in `dist/` containing `ImageBlur.app`.
The packaged app is ad hoc signed by default so Sparkle can validate updates correctly.

## Updates
Packaged releases can use Sparkle for update checks.

To enable this for your own builds, provide:
- `SPARKLE_APPCAST_URL`
- `SPARKLE_PUBLIC_ED_KEY`

```bash
export SPARKLE_APPCAST_URL="https://example.com/imageblur/appcast.xml"
export SPARKLE_PUBLIC_ED_KEY="your-public-ed25519-key"
./scripts/build_release.sh v0.1.0
```

Without both values, Sparkle stays disabled.

If you want to replace the default ad hoc signature with your own certificate, set `APP_CODESIGN_IDENTITY` before building the archive.

## Supported Formats
- PNG
- JPEG / JPG
- TIFF
- HEIC, when supported by the system

## Notes
- Export keeps the original pixel dimensions and file format.
- JPEG exports are re-encoded, so they are not byte-identical to the source file.
- Lasso regions can be transformed as a whole, but their points are not individually editable yet.

## AI Disclaimer
Parts of this project were created or refined with the help of AI-assisted development tools. All generated output should be treated as human-reviewed project code and documentation, not as an authoritative source on its own.

## Development
For engineering conventions and repo-specific implementation notes, see [AGENTS.md](AGENTS.md).

## License
This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for details.
