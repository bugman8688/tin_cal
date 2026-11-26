#!/bin/bash
set -euo pipefail

# 从 Resources/AppIcon.svg 生成 Resources/AppIcon.icns。
# 依赖：rsvg-convert（Homebrew librsvg）、iconutil（macOS 自带）。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$ROOT/Resources/AppIcon.svg"
OUT="$ROOT/Resources/AppIcon.icns"

if ! command -v rsvg-convert >/dev/null 2>&1; then
	echo "缺少 rsvg-convert，请先执行：brew install librsvg" >&2
	exit 1
fi

WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

render() {
	rsvg-convert -w "$1" -h "$1" "$SVG" -o "$ICONSET/$2"
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUT"
echo "==> 已生成 ${OUT#$ROOT/}"
