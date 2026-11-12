#!/bin/bash
# 生成 AppIcon.icns：先画 1024 母版，再导出 iconset。
set -euo pipefail

cd "$(dirname "$0")/.."

swift scripts/make-icon.swift

ICONSET="App/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16 App/AppIcon-1024.png --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 App/AppIcon-1024.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 App/AppIcon-1024.png --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 App/AppIcon-1024.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 App/AppIcon-1024.png --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 App/AppIcon-1024.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 App/AppIcon-1024.png --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 App/AppIcon-1024.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 App/AppIcon-1024.png --out "$ICONSET/icon_512x512.png" >/dev/null
cp App/AppIcon-1024.png "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o App/AppIcon.icns
rm -rf "$ICONSET"

echo "已生成 App/AppIcon.icns"
