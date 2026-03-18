#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(git describe --tags --always --dirty)}"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$DIST_DIR/ImageBlur-${VERSION}-macos.dmg"
EXTRA_BUILD_FLAGS=()

if [[ -n "${SWIFT_BUILD_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  EXTRA_BUILD_FLAGS=(${SWIFT_BUILD_FLAGS})
fi

mkdir -p "$DIST_DIR"

if ((${#EXTRA_BUILD_FLAGS[@]} > 0)); then
  swift build "${EXTRA_BUILD_FLAGS[@]}" -c release
else
  swift build -c release
fi
"$ROOT_DIR/scripts/assemble_app.sh" release "$DIST_DIR"
"$ROOT_DIR/scripts/configure_sparkle.sh" "$DIST_DIR/ImageBlur.app"

rm -f "$ARCHIVE_PATH"

DMG_STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$DMG_STAGING_DIR"
}
trap cleanup EXIT

cp -R "$DIST_DIR/ImageBlur.app" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "ImageBlur" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$ARCHIVE_PATH"

echo "Created $ARCHIVE_PATH"
