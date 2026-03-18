# Contributing to ImageBlur

Thanks for contributing.

## Local setup
```bash
swift build
swift run
```

For a release-style local package:
```bash
swift build -c release
./scripts/assemble_app.sh release
```

## Development expectations
- Keep changes focused and easy to review.
- Preserve the current user-visible behavior unless the change explicitly updates it.
- If you change rendering, selection, zoom, or export behavior, verify both the live preview and the exported image.
- If you change packaging or release scripts, verify the generated `.app` bundle and release zip locally.

## Pull requests
- Use a short, descriptive title.
- Explain the user-facing impact and any behavior changes.
- Mention verification steps you ran, at minimum `swift build`.
- Include screenshots or short recordings for visible UI changes when possible.

## Style notes
- Follow the existing SwiftUI and Swift Package Manager structure.
- Keep geometry and editor interaction logic readable and explicit.
- Prefer small helper methods over deeply nested gesture logic.

## Before opening a PR
- Run:
  - `swift build`
- If relevant, also run:
  - `swift build -c release`
  - `./scripts/assemble_app.sh release`
  - `./scripts/build_release.sh test-build`
