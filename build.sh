#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 Building Todo Mac application..."

mkdir -p /tmp/clang-cache

# Compile Swift sources with swiftc
swiftc -O -parse-as-library \
    -module-cache-path /tmp/clang-cache \
    Sources/TodoApp/TodoApp.swift \
    Sources/TodoApp/Models/*.swift \
    Sources/TodoApp/Services/*.swift \
    Sources/TodoApp/Store/*.swift \
    Sources/TodoApp/Views/*.swift \
    -o TodoApp

echo "📦 Creating macOS Application Bundle (Todo.app)..."
APP_BUNDLE="Todo.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp TodoApp "$APP_BUNDLE/Contents/MacOS/TodoApp"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

# Generate AppIcon.icns from icon.png (all sizes) whenever the source changes
if [ -f "icon.png" ] && command -v iconutil >/dev/null 2>&1; then
    if [ ! -f "AppIcon.icns" ] || [ "icon.png" -nt "AppIcon.icns" ]; then
        echo "🎨 Generating app icon from icon.png..."
        ICONSET="AppIcon.iconset"
        rm -rf "$ICONSET"
        mkdir -p "$ICONSET"
        for size in 16 32 128 256 512; do
            double=$((size * 2))
            sips -z "$size" "$size" icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
            sips -z "$double" "$double" icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
        done
        iconutil -c icns "$ICONSET" -o AppIcon.icns
        rm -rf "$ICONSET"
    fi
fi

if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc code sign for seamless local execution on macOS
if command -v codesign >/dev/null 2>&1; then
    echo "✍️ Signing application bundle..."
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "✨ Build completed successfully!"
echo "🚀 You can launch the app by double-clicking 'Todo.app' or running:"
echo "   open Todo.app"
