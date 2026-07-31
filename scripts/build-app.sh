#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/PaperPrism.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
ARCH="$(uname -m)"

SDK_PATH="${SDKROOT:-}"
if [[ -z "$SDK_PATH" ]]; then
  SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
fi

if [[ "$APP_DIR" != "$PROJECT_DIR/.build/PaperPrism.app" ]]; then
  echo "Unexpected app output path: $APP_DIR" >&2
  exit 1
fi
/bin/rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

SOURCE_FILES=()
while IFS= read -r source_file; do
  SOURCE_FILES+=("$source_file")
done < <(find "$PROJECT_DIR/Sources/PaperPrism" -name '*.swift' -print | sort)

swiftc \
  -Xfrontend -experimental-allow-module-with-compiler-errors \
  -parse-as-library \
  -O \
  -sdk "$SDK_PATH" \
  -target "$ARCH-apple-macosx13.0" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework SwiftUI \
  -framework PDFKit \
  -framework UniformTypeIdentifiers \
  -o "$MACOS_DIR/PaperPrism" \
  "${SOURCE_FILES[@]}"

cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

if [[ -e "$RESOURCES_DIR/Tools" ]]; then
  echo "Refusing to package Resources/Tools; external agents must remain user-supplied." >&2
  exit 1
fi

chmod +x "$MACOS_DIR/PaperPrism"

printf '%s\n' "$APP_DIR"
