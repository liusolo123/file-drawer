#!/bin/bash
# 生成可发给他人体验的 DMG：应用 + Applications 快捷方式 + 体验说明。
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="0.1.0"
APP_NAME="文件抽屉"
APP_PATH="dist/${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}-${VERSION}.dmg"
STAGE="dist/dmg-stage"

./scripts/build-app.sh

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "App/体验说明.txt" "$STAGE/体验说明.txt"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGE"

echo "已生成：$DMG_PATH"
echo "大小：$(du -h "$DMG_PATH" | cut -f1)"
