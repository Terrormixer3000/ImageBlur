#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONFIGURATION="${1:-debug}"
OUTPUT_DIR="${2:-$ROOT_DIR}"
EXTRA_BUILD_FLAGS=()

if [[ -n "${SWIFT_BUILD_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  EXTRA_BUILD_FLAGS=(${SWIFT_BUILD_FLAGS})
fi

if ((${#EXTRA_BUILD_FLAGS[@]} > 0)); then
  BUILD_DIR="$(swift build "${EXTRA_BUILD_FLAGS[@]}" -c "$BUILD_CONFIGURATION" --show-bin-path)"
else
  BUILD_DIR="$(swift build -c "$BUILD_CONFIGURATION" --show-bin-path)"
fi
APP_DIR="$OUTPUT_DIR/ImageBlur.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$BUILD_DIR/ImageBlur" "$MACOS_DIR/ImageBlur"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# SwiftPM does not produce an app bundle for us, so we need to add the bundle
# framework rpath explicitly. Sparkle is linked as @rpath/Sparkle.framework/...
# and would otherwise only search next to the executable.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/ImageBlur"

if [[ -n "${APP_VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$CONTENTS_DIR/Info.plist"
fi

if [[ -n "${APP_BUILD_NUMBER:-}" ]]; then
  plutil -replace CFBundleVersion -string "$APP_BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
fi

while IFS= read -r -d '' resource_bundle; do
  cp -R "$resource_bundle" "$RESOURCES_DIR/"
  bundle_name="$(basename "$resource_bundle")"
  ln -sfn "Contents/Resources/$bundle_name" "$APP_DIR/$bundle_name"
done < <(find "$BUILD_DIR" -maxdepth 1 -type d -name '*.bundle' -print0)

while IFS= read -r -d '' framework; do
  ditto "$framework" "$FRAMEWORKS_DIR/$(basename "$framework")"
done < <(find "$BUILD_DIR" -maxdepth 1 -type d -name '*.framework' -print0)

chmod +x "$MACOS_DIR/ImageBlur"

echo "Created $APP_DIR"
