#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 v0.1.0"
  exit 1
fi

VERSION="$1"
NAME="seer"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/.build/release-artifacts"

mkdir -p "$OUT_DIR" "$BUILD_DIR"

swift build -c release --arch arm64

BIN="$ROOT_DIR/.build/release/$NAME"
[[ -f "$BIN" ]] || BIN="$ROOT_DIR/.build/arm64-apple-macosx/release/$NAME"
if [[ ! -f "$BIN" ]]; then
  echo "Could not locate release binary at $BIN"
  exit 1
fi

cp "$BIN" "$BUILD_DIR/$NAME"
chmod +x "$BUILD_DIR/$NAME"

ARCHIVE="$OUT_DIR/$NAME-${VERSION#v}-arm64-macos.tar.gz"
tar -C "$BUILD_DIR" -czf "$ARCHIVE" "$NAME"

SHA256=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
echo "Archive: $ARCHIVE"
echo "SHA256: $SHA256"
