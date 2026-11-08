#!/bin/zsh
# Builds "Tubemac.app" (universal: Apple Silicon + Intel) into ./build.
#   ./build.sh            build only
#   ./build.sh --install  build and copy to /Applications
#   ./build.sh --zip      build and create build/Tubemac.zip for a release
# APP_NAME, BUNDLE_ID and ICON_SCRIPT can be overridden via environment variables.
set -euo pipefail
cd "${0:A:h}"

APP_NAME="${APP_NAME:-Tubemac}"
BUNDLE_ID="${BUNDLE_ID:-io.github.claudimoret.tubemac}"
ICON_SCRIPT="${ICON_SCRIPT:-Tools/make-icon.swift}"
VERSION="1.1.0"
EXECUTABLE="Tubemac"
APP="build/$APP_NAME.app"

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos14.0" \
    -framework AppKit -framework WebKit \
    -o "build/$EXECUTABLE-$arch" Sources/main.swift
done
lipo -create -output "$APP/Contents/MacOS/$EXECUTABLE" "build/$EXECUTABLE-arm64" "build/$EXECUTABLE-x86_64"
rm "build/$EXECUTABLE-arm64" "build/$EXECUTABLE-x86_64"

swift "$ICON_SCRIPT" build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Tubemac – unofficial YouTube Music app for Mac. Not affiliated with Google LLC.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built: $APP"

case "${1:-}" in
  --install)
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "Installed: /Applications/$APP_NAME.app"
    ;;
  --zip)
    ditto -c -k --keepParent "$APP" "build/${APP_NAME// /-}.zip"
    echo "Zipped: build/${APP_NAME// /-}.zip"
    ;;
esac
