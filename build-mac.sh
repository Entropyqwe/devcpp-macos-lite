#!/bin/bash
# Build & bundle "Dev C++ for macOS" from source on THIS machine (any Mac).
#
# The resulting app is ad-hoc signed locally, so on THIS machine it runs with
# NO signing bypass at all. You only need Xcode Command Line Tools:
#     xcode-select --install
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# Sources live in ./src when present, else next to this script.
SRC="$HERE/src"; [ -d "$SRC" ] || SRC="$HERE"
APP_NAME="DevCppMac"

echo "==> 1/4 compiling ($(uname -m))"
swiftc -O -target "$(uname -m)"-apple-macosx13.0 \
  -o "$HERE/$APP_NAME.bin" \
  "$SRC/AppMain.swift" "$SRC/Editor.swift" "$SRC/Core.swift"

echo "==> 2/4 assembling .app bundle"
APP="$HERE/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/$APP_NAME.bin" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Dev C++ for macOS</string>
  <key>CFBundleDisplayName</key><string>Dev C++ for macOS</string>
  <key>CFBundleIdentifier</key><string>com.devmac.dev-cpp</string>
  <key>CFBundleExecutable</key><string>DevCppMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict></plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"
[ -f "$HERE/AppIcon.icns" ] && cp "$HERE/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> 3/4 ad-hoc signing"
codesign --force --deep --sign - "$APP"

rm -f "$HERE/$APP_NAME.bin"

echo "==> 4/4 done"
echo "Built: $APP"
echo
echo "To install:  cp -R \"$APP\" /Applications/"
echo "Or open it :  open \"$APP\""
