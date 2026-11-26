#!/bin/bash
set -euo pipefail

# 一条命令完成：构建 → 安装到 /Applications → 重启 → 验证进程。
# 配合自定义权限规则中的 `./scripts/*` 白名单，整个流程不会逐条触发审批。
#
# 为什么必须安装到 /Applications 再启动：
# macOS 27 的菜单栏项布局按 app 路径持久化，从 dist/ 等其它路径启动的同 bundle ID
# 副本会被系统当成新项收纳，NSStatusItem 不显示（进程能跑但菜单栏看不到时间）。
# 只有 /Applications 下的副本能稳定沿用已保存的可见槽位。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLED_APP="/Applications/TinCal.app"

"$ROOT/scripts/build.sh" install

sleep 2

if PID_OUTPUT="$(pgrep -x TinCal)"; then
	PID="$(echo "$PID_OUTPUT" | head -n 1)"
	echo "==> 运行中，PID ${PID}（${INSTALLED_APP}）"
else
	echo "==> 启动失败：未检测到 TinCal 进程" >&2
	exit 1
fi
