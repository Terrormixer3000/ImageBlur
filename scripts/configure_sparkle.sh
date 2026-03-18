#!/usr/bin/env bash

set -euo pipefail

APP_PATH="${1:?Usage: configure_sparkle.sh /path/to/ImageBlur.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
SPARKLE_APPCAST_URL="${SPARKLE_APPCAST_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist at $INFO_PLIST" >&2
  exit 1
fi

if [[ -z "$SPARKLE_APPCAST_URL" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "Sparkle is not configured; skipping."
  exit 0
fi

if [[ -z "$SPARKLE_APPCAST_URL" || -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "Both SPARKLE_APPCAST_URL and SPARKLE_PUBLIC_ED_KEY must be set together." >&2
  exit 1
fi

plutil -replace SUFeedURL -string "$SPARKLE_APPCAST_URL" "$INFO_PLIST" 2>/dev/null || \
  plutil -insert SUFeedURL -string "$SPARKLE_APPCAST_URL" "$INFO_PLIST"
plutil -replace SUPublicEDKey -string "$SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST" 2>/dev/null || \
  plutil -insert SUPublicEDKey -string "$SPARKLE_PUBLIC_ED_KEY" "$INFO_PLIST"
plutil -replace SUEnableAutomaticChecks -bool YES "$INFO_PLIST" 2>/dev/null || \
  plutil -insert SUEnableAutomaticChecks -bool YES "$INFO_PLIST"

echo "Configured Sparkle in $APP_PATH"
