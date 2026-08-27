#!/bin/bash
set -euo pipefail

VERSION="${1:-v1.0.0}"
VERSION_NUMBER="${VERSION#v}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$(cd "$ROOT_DIR" && swift build --configuration release --show-bin-path)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/JBChat.app"
CONTENTS_DIR="$APP_DIR/Contents"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/LongChat" "$CONTENTS_DIR/MacOS/LongChat"

for bundle in "$BIN_DIR"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "$CONTENTS_DIR/Resources/"
    fi
done

PLIST_PATH="$CONTENTS_DIR/Info.plist"
plutil -create xml1 "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDevelopmentRegion string zh_CN' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string JBChat' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundleExecutable string LongChat' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIdentifier string com.hellokerenqian.jbchat' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundleInfoDictionaryVersion string 6.0' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundleName string JBChat' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :CFBundlePackageType string APPL' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION_NUMBER" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION_NUMBER" "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :LSMinimumSystemVersion string 26.0' "$PLIST_PATH"
/usr/libexec/PlistBuddy -c 'Add :NSHighResolutionCapable bool true' "$PLIST_PATH"

codesign --force --deep --sign - "$APP_DIR"

ARCHIVE="$DIST_DIR/JBChat-$VERSION-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
echo "$ARCHIVE"
