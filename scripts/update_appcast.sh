#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: update_appcast.sh <appcast-dir> <archive-path> <download-url> <version> <build-number>" >&2
  exit 1
fi

APPCAST_DIR="$1"
ARCHIVE_PATH="$2"
DOWNLOAD_URL="$3"
VERSION="$4"
BUILD_NUMBER="$5"
APPCAST_FILE="$APPCAST_DIR/appcast.xml"
APPCAST_TITLE="${APPCAST_TITLE:-ImageBlur Updates}"
APPCAST_LINK="${APPCAST_LINK:-https://github.com/Terrormixer3000/image_blur}"
APPCAST_DESCRIPTION="${APPCAST_DESCRIPTION:-Latest ImageBlur releases.}"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-14.0}"
ARCHIVE_EXTENSION="${ARCHIVE_PATH##*.}"

case "$ARCHIVE_EXTENSION" in
  dmg)
    CONTENT_TYPE="application/x-apple-diskimage"
    ;;
  zip)
    CONTENT_TYPE="application/zip"
    ;;
  *)
    CONTENT_TYPE="application/octet-stream"
    ;;
esac

mkdir -p "$APPCAST_DIR"

if [[ -n "${SPARKLE_ED_SIGNATURE:-}" ]]; then
  ED_SIGNATURE="$SPARKLE_ED_SIGNATURE"
else
  if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    echo "SPARKLE_PRIVATE_KEY or SPARKLE_ED_SIGNATURE must be set." >&2
    exit 1
  fi

  SIGN_TOOL="${SPARKLE_SIGN_TOOL:-$(find .build -path '*/artifacts/sparkle/Sparkle/bin/sign_update' -type f | head -1)}"
  if [[ -z "$SIGN_TOOL" || ! -x "$SIGN_TOOL" ]]; then
    echo "Could not find Sparkle sign_update tool." >&2
    exit 1
  fi

  ED_SIGNATURE="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_TOOL" --ed-key-file - -p "$ARCHIVE_PATH")"
fi

FILE_SIZE="$(stat -f%z "$ARCHIVE_PATH")"
PUB_DATE="$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")"
TMP_EXISTING="$(mktemp)"
TMP_FILTERED="$(mktemp)"
TMP_APPCAST="$(mktemp)"

cleanup() {
  rm -f "$TMP_EXISTING" "$TMP_FILTERED" "$TMP_APPCAST"
}
trap cleanup EXIT

if [[ -f "$APPCAST_FILE" ]]; then
  cp "$APPCAST_FILE" "$TMP_EXISTING"
else
  cat > "$TMP_EXISTING" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>${APPCAST_TITLE}</title>
    <link>${APPCAST_LINK}</link>
    <description>${APPCAST_DESCRIPTION}</description>
    <language>en</language>
  </channel>
</rss>
EOF
fi

awk -v version="$VERSION" -v build="$BUILD_NUMBER" '
  BEGIN {
    in_item = 0
    item = ""
  }
  /<item>/ {
    in_item = 1
    item = $0 ORS
    next
  }
  in_item {
    item = item $0 ORS
    if ($0 ~ /<\/item>/) {
      if (item !~ ("<sparkle:shortVersionString>" version "</sparkle:shortVersionString>") &&
          item !~ ("<sparkle:version>" build "</sparkle:version>")) {
        printf "%s", item
      }
      in_item = 0
      item = ""
    }
    next
  }
  { print }
' "$TMP_EXISTING" > "$TMP_FILTERED"

awk \
  -v version="$VERSION" \
  -v pub_date="$PUB_DATE" \
  -v build="$BUILD_NUMBER" \
  -v url="$DOWNLOAD_URL" \
  -v signature="$ED_SIGNATURE" \
  -v size="$FILE_SIZE" \
  -v minimum_system_version="$MINIMUM_SYSTEM_VERSION" \
  -v content_type="$CONTENT_TYPE" '
  /<\/channel>/ {
    print "    <item>"
    print "      <title>Version " version "</title>"
    print "      <pubDate>" pub_date "</pubDate>"
    print "      <sparkle:version>" build "</sparkle:version>"
    print "      <sparkle:shortVersionString>" version "</sparkle:shortVersionString>"
    print "      <sparkle:minimumSystemVersion>" minimum_system_version "</sparkle:minimumSystemVersion>"
    print "      <enclosure url=\"" url "\""
    print "                 sparkle:edSignature=\"" signature "\""
    print "                 length=\"" size "\""
    print "                 type=\"" content_type "\"/>"
    print "    </item>"
  }
  { print }
' "$TMP_FILTERED" > "$TMP_APPCAST"

mv "$TMP_APPCAST" "$APPCAST_FILE"

echo "Updated $APPCAST_FILE"
