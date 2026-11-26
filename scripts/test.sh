#!/bin/bash
set -euo pipefail

# CLT 环境下 swift-testing 宏插件不在默认搜索路径，需要显式传 -plugin-path。
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"

if [[ -d "$PLUGIN_DIR" ]]; then
	echo "==> 使用 TestingMacros 插件路径：$PLUGIN_DIR"
	swift test --package-path "$ROOT" -Xswiftc -plugin-path -Xswiftc "$PLUGIN_DIR" "$@"
else
	echo "==> 未检测到 TestingMacros 插件目录，直接运行 swift test"
	swift test --package-path "$ROOT" "$@"
fi
