#!/bin/bash
# 用独立构建目录跑测试。
#
# 背景：当前只有 Command Line Tools 的 Swift 6.4 工具链里，SwiftPM 偶尔会在
# 增量构建时丢失 TestingMacros 插件的解析结果，报
# "plugin for module 'TestingMacros' not found"。独立 scratch 目录能避免与
# 应用构建互相污染；仍出现时自动清理并重试一次。
set -euo pipefail

cd "$(dirname "$0")/.."

SCRATCH_DIR=".build-test"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

if swift test --scratch-path "$SCRATCH_DIR" "$@" >"$LOG" 2>&1; then
    cat "$LOG"
    exit 0
fi

if grep -q "TestingMacros" "$LOG"; then
    echo "检测到 SwiftPM 宏插件缓存异常，清理 $SCRATCH_DIR 后重试…"
    rm -rf "$SCRATCH_DIR"
    swift test --scratch-path "$SCRATCH_DIR" "$@"
else
    cat "$LOG"
    exit 1
fi
