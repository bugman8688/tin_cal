# 构建与部署

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：打包、签名、安装与发版 | hanbing | 2026-11-26 |

## 两条命令的区别

| 命令 | 产物 | 用途 |
| --- | --- | --- |
| `swift build` | `.build/` 下的可执行文件 | 只验证能否编译，**不能用来运行验证** |
| `./scripts/build.sh` | `dist/TinCal.app` + 启动 | 组装并签名，从 `dist/` 启动，**不用于运行验证** |
| `./scripts/build.sh install` | `/Applications/TinCal.app` + 启动 | 真机验证与日常使用的唯一正确方式 |
| `./scripts/restart.sh` | 同上 | `install` + 进程校验，日常首选 |

> 从 `dist/` 启动会出现菜单栏项缺失等异常，因为菜单栏槽位按 app 路径持久化。

## 打包流程（`scripts/build.sh`）

1. `killall TinCal`，避免替换正在运行的包。
2. `swift build -c release`。
3. 组装 `dist/TinCal.app`：可执行文件进 `Contents/MacOS/`，`Info.plist`、`holiday_snapshot.json`、`AppIcon.icns` 进 `Contents/Resources/`。
4. 用固定证书 `TinCal Dev Signature` 签名。
5. `codesign --verify --deep --strict` 校验，并确认 Authority 就是该证书。
6. `install` 模式：先复制到 `/Applications/.TinCal.app.staging` 校验，通过后把现有包移到 `.previous`，替换成功再删除；任一步校验失败自动回滚。

## 签名约束

| 约束 | 原因 |
| --- | --- |
| 必须用固定证书 `TinCal Dev Signature`，不允许 ad-hoc | ad-hoc 的 designated requirement 基于 cdhash，每次构建都变，重装必弹提醒事项授权窗；固定证书只绑定 bundle id + 证书，覆盖安装保留 TCC 授权 |
| 证书缺失时脚本直接中止 | 防止静默回退 ad-hoc 造成授权重置 |
| 临时验证可用 `ALLOW_ADHOC=1 ./scripts/build.sh` | 显式选择降级，脚本会警告「每次重装都会触发授权重置」 |
| 沙箱 / 自动化环境会报 `errSecInternalComponent` | 无法访问钥匙串私钥，需在真实终端执行 |

## 升级 / 替换

```bash
./scripts/build.sh install
```

脚本自己会杀旧进程、暂存校验、失败回滚，**不要**手动删 `/Applications/TinCal.app` 再拷贝。

## 开机自启

- 实现为 `SMAppService.mainApp`（`LoginItemManager`）。
- **前提：`.app` 必须在 `/Applications`**，否则注册失败。从 `dist/` 或其它路径启动时设置页应提示用户执行 `./scripts/build.sh install`。
- 用户拒绝或系统限制时，设置页展示状态并提供跳转系统设置的入口。

## 首次安装的授权

1. 打开面板触发提醒事项授权弹窗，允许。
2. 若曾被拒绝：系统设置 → 隐私与安全性 → 提醒事项 → 勾选 TinCal。
3. 换签名证书会导致 TCC 记录失效，授权需要重做——这也是必须固定证书的原因。

## 发版检查清单

- [ ] `swift build` 通过
- [ ] `./scripts/test.sh` 全绿
- [ ] `./scripts/build.sh install` 签名与校验通过
- [ ] 菜单栏时间正常显示，面板可开合
- [ ] 提醒事项授权状态正确（首次 / 已授权 / 被拒三条路径）
- [ ] 若改了图标：`./scripts/make-icon.sh` 后重新打包
- [ ] 若改了节假日快照：确认 `Resources/holiday_snapshot.json` 已更新并被打进包
