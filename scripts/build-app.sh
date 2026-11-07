#!/bin/bash
# 组装可双击运行的 .app，不依赖 xcodebuild。
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
EXECUTABLE_NAME="FileDrawer"
APP_NAME="文件抽屉"
APP_PATH="dist/${APP_NAME}.app"

swift build -c "$CONFIG" --product FileDrawerApp
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

cp "$BIN_DIR/FileDrawerApp" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
cp App/Info.plist "$APP_PATH/Contents/Info.plist"

if ! codesign --force --sign - "$APP_PATH" >/dev/null 2>&1; then
    echo "警告：ad-hoc 签名失败，应用仍可在本机运行"
fi

echo "已生成：$APP_PATH"
