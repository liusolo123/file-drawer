#!/bin/bash
# 用独立构建目录跑测试。
#
# 背景：
# 1. 当前工具链（Command Line Tools + Swift 6.4）偶尔会在增量构建时丢失
#    TestingMacros 插件的解析结果，报 "plugin for module 'TestingMacros' not found"。
#    独立 scratch 目录可避免与应用构建互相污染。
# 2. SwiftPM 的默认沙盒会阻止加载工具链里的该插件，必须加 --disable-sandbox。
set -euo pipefail

cd "$(dirname "$0")/.."

SCRATCH_DIR=".build-test"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

if swift test --scratch-path "$SCRATCH_DIR" --disable-sandbox "$@" >"$LOG" 2>&1; then
    cat "$LOG"
    exit 0
fi

if grep -q "TestingMacros" "$LOG"; then
    echo "检测到 SwiftPM 宏插件异常，清理 $SCRATCH_DIR 后重试…"
    rm -rf "$SCRATCH_DIR"
    swift test --scratch-path "$SCRATCH_DIR" --disable-sandbox "$@"
else
    cat "$LOG"
    exit 1
fi
