# 快速上手

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：从零跑通 tin_cal | hanbing | 2026-11-26 |

目标：5 分钟内让菜单栏显示日历与时间，并能在面板里看到当天的待办。

## 前置条件

| 项 | 要求 |
| --- | --- |
| 系统 | macOS 14 及以上 |
| 工具链 | 只需 Command Line Tools（`xcode-select --install`），**不需要 Xcode** |
| 签名证书 | 打包安装时需要钥匙串里有 `TinCal Dev Signature`（仅 `swift build` 调试不需要） |

## 1. 编译

```bash
swift build
```

只验证语法与链接，产物在 `.build/` 下，不生成 App 包。

## 2. 打包并安装

```bash
./scripts/build.sh install
```

这一步会：杀旧进程 → release 编译 → 组装 `dist/TinCal.app` → 用固定证书签名 → 安装到 `/Applications` → 启动。

> 为什么不直接从 `dist/` 运行：菜单栏项的位置按 app 路径持久化，从其它路径启动同 bundle id 的副本会被系统当成新项收纳，`NSStatusItem` 不显示（进程在跑但菜单栏看不到）。

## 3. 日常改完代码后重启

```bash
./scripts/restart.sh
```

等价于 `build.sh install` + 进程校验，是日常首选。

## 4. 授权提醒事项

首次点击菜单栏时间打开面板时，系统会弹出提醒事项授权。

- 允许 → 面板底部可展开当天的未完成待办，月历格子在有待办的日期亮小灯泡。
- 拒绝 → 列表区显示引导卡，点「打开系统设置」跳隐私设置；也可从右键菜单进「设置」查看状态。
- 授权状态只在 `.notDetermined` 时自动发起请求，被拒后需手动去系统设置改。

## 5. 使用

| 操作 | 效果 |
| --- | --- |
| 左键点菜单栏时间 | 开 / 关面板 |
| 右键点菜单栏时间 | 菜单：设置 / 关于 / 退出 |
| 点某一天 | 选中该日，若该日有未过期待办则从底部展开列表；再点一次收起 |
| 双指横滑（面板内） | 上 / 下个月 |
| 点头部「今天」 | 回到当月 |
| 点某条待办 | 唤起系统「提醒事项」App（TinCal 只读，不做编辑） |

## 6. 退出

```bash
killall TinCal
```

或右键菜单 →「退出 TinCal」。

## 下一步

- 想改代码：[development-guide.md](development-guide.md)
- 想打包发版：[deployment.md](deployment.md)
- 想看设计思路：[architecture/overview.md](architecture/overview.md)
