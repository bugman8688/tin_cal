#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-build}"

if [[ "$MODE" != "build" && "$MODE" != "install" ]]; then
    printf '未知参数：%s（仅支持 build / install）\n' "$MODE" >&2
    exit 1
fi

APP="$ROOT/dist/TinCal.app"

echo "==> 停止正在运行的 TinCal"
killall TinCal 2>/dev/null || true

echo "==> 编译（release）"
swift build -c release --package-path "$ROOT"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"

echo "==> 组装 ${APP#$ROOT/}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TinCal" "$APP/Contents/MacOS/TinCal"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/holiday_snapshot.json" "$APP/Contents/Resources/holiday_snapshot.json"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> 签名（固定证书，缺失时拒绝安装）"
# 固定证书的 designated requirement 只绑定 bundle id + 证书（不含二进制哈希），
# 同一张证书下覆盖安装不会清空 TCC 授权，避免每次发布都重弹系统授权窗。
# ad-hoc 的 requirement 基于 cdhash、每次构建都会变，重装必弹授权窗，因此不再静默回退。
SIGN_IDENTITY="TinCal Dev Signature"
identities="$(security find-identity -v -p codesigning 2>&1 || true)"
if [[ "$identities" != *"$SIGN_IDENTITY"* ]]; then
    if [[ "${ALLOW_ADHOC:-0}" == "1" ]]; then
        printf '警告：钥匙串缺少证书「%s」，已按 ALLOW_ADHOC=1 回退 ad-hoc 签名。\n此包每次重装都会触发系统授权重置，仅用于临时验证。\n' "$SIGN_IDENTITY" >&2
        codesign --force --sign - "$APP"
    else
        printf '缺少签名证书「%s」，安装中止。\n请创建该证书；如确需临时打包，可设 ALLOW_ADHOC=1 跳过。\n' "$SIGN_IDENTITY" >&2
        exit 1
    fi
else
    if ! sign_out=$(codesign --force --sign "$SIGN_IDENTITY" "$APP" 2>&1); then
        printf '签名失败：%s\n常见原因：自动化 / 沙箱环境无法访问钥匙串私钥，或钥匙串被锁。请在真实终端重试。\n' "$sign_out" >&2
        exit 1
    fi
fi

echo "==> 校验签名"
if ! codesign --verify --deep --strict "$APP"; then
    printf '签名校验失败：%s 已损坏，安装中止，避免把坏包装到 /Applications。\n' "$APP" >&2
    exit 1
fi
sign_info="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if [[ "${ALLOW_ADHOC:-0}" != "1" ]] && [[ "$sign_info" != *"Authority=$SIGN_IDENTITY"* ]]; then
    printf '签名身份不是「%s」，安装中止。\n' "$SIGN_IDENTITY" >&2
    exit 1
fi

if [[ "$MODE" == "install" ]]; then
    echo "==> 安装到 /Applications/TinCal.app（暂存校验后替换，保留旧包回滚）"
    STAGE="/Applications/.TinCal.app.staging"
    PREV="/Applications/.TinCal.app.previous"
    if [[ -d "$PREV" && ! -d "/Applications/TinCal.app" ]]; then
        mv "$PREV" "/Applications/TinCal.app"
    fi
    rm -rf "$STAGE" "$PREV"
    ditto "$APP" "$STAGE"
    if ! codesign --verify --deep --strict "$STAGE"; then
        rm -rf "$STAGE"
        printf '新包签名校验失败，安装中止，原版本未改动。\n' >&2
        exit 1
    fi
    if [[ -d "/Applications/TinCal.app" ]]; then
        mv "/Applications/TinCal.app" "$PREV"
    fi
    mv "$STAGE" "/Applications/TinCal.app"
    if ! codesign --verify --deep --strict "/Applications/TinCal.app"; then
        rm -rf "/Applications/TinCal.app"
        if [[ -d "$PREV" ]]; then mv "$PREV" "/Applications/TinCal.app"; fi
        printf '安装后校验失败，已回滚到原版本。\n' >&2
        exit 1
    fi
    rm -rf "$PREV"
    echo "==> 启动 /Applications/TinCal.app"
    open "/Applications/TinCal.app"
else
    echo "==> 启动 ${APP#$ROOT/}"
    open "$APP"
fi
