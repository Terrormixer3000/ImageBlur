#!/usr/bin/env bash

set -euo pipefail

APP_PATH="${1:?Usage: sign_app.sh /path/to/ImageBlur.app}"
SIGNING_IDENTITY="${APP_CODESIGN_IDENTITY:--}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle at $APP_PATH" >&2
  exit 1
fi

codesign_args=(
  --force
  --sign "$SIGNING_IDENTITY"
)

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign_args+=(--timestamp=none)
else
  codesign_args+=(--timestamp)
fi

codesign "${codesign_args[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Signed $APP_PATH with identity $SIGNING_IDENTITY"
