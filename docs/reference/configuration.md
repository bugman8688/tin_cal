# 配置项参考

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：设置项、Info.plist、脚本参数、文件位置 | hanbing | 2026-11-26 |

## 用户设置（UserDefaults）

存储于标准 `UserDefaults`，键名前缀统一 `settings.`，定义在 `SettingsStore.Key`。

| 键 | 类型 | 默认值 | 含义 |
| --- | --- | --- | --- |
| `settings.use24Hour` | Bool | `true` | 24 小时制；关闭后显示「下午3:41」形式 |
| `settings.showWeekday` | Bool | `true` | 菜单栏是否带周几 |
| `settings.showSeconds` | Bool | `false` | 菜单栏是否显示秒 |
| `settings.primarySourceID` | String | `github` | 节假日主源，取值见下表 |

### 节假日源（`HolidaySource`）

| `rawValue` | 显示名 | 取数方式 | 备注 |
| --- | --- | --- | --- |
| `github` | GitHub raw | 按年 | 数据最新，国内可能较慢 |
| `jsdelivr` | jsDelivr | 按年 | CDN 缓存，速度较快 |
| `npmmirror` | npmmirror | 全量 | 国内镜像，年份参数被忽略 |

> 主源只是「优先尝试」，失败后仍会依次尝试其余两个源、本地缓存、内置快照，见 [ADR-0003](../architecture/adr/0003-holiday-fallback-chain.md)。

## Info.plist 关键键

`Resources/Info.plist` 会被 `scripts/build.sh` 原样复制进 App 包。

| 键 | 值 | 说明 |
| --- | --- | --- |
| `CFBundleIdentifier` | `local.hanbing.tincal` | 签名与 TCC 授权都绑定此值，不可随意改 |
| `LSUIElement` | `true` | 不显示 Dock 图标，只驻留菜单栏 |
| `CFBundleShortVersionString` | `1.0.0` | 展示版本 |
| `CFBundleVersion` | `1` | 构建号 |
| `LSMinimumSystemVersion` | `14.0` | 最低系统版本 |
| `NSRemindersUsageDescription` | 文案 | 提醒事项授权说明 |
| `NSRemindersFullAccessUsageDescription` | 文案 | 完整访问权限说明 |

## 脚本参数

| 脚本 | 参数 / 环境变量 | 行为 |
| --- | --- | --- |
| `scripts/build.sh` | 无参数（默认 `build`） | 组装 `dist/TinCal.app` 并签名，随后从 `dist/` 启动 |
| `scripts/build.sh` | `install` | 组装签名后安装到 `/Applications` 并启动 |
| `scripts/build.sh` | `ALLOW_ADHOC=1` | 证书缺失时降级 ad-hoc 签名（仅供临时验证，会重置 TCC） |
| `scripts/test.sh` | 透传给 `swift test` | 自动补 TestingMacros 插件路径 |
| `scripts/restart.sh` | 无 | `build.sh install` + 进程校验 |
| `scripts/make-icon.sh` | 无 | 由 `Resources/AppIcon.svg` 生成 `AppIcon.icns`，依赖 `rsvg-convert`（`brew install librsvg`） |

## 运行时文件位置

| 文件 | 路径 | 说明 |
| --- | --- | --- |
| 节假日缓存 | `~/Library/Application Support/tin_cal/holiday_cache.json` | 最近一次成功拉取的结果，含 `updatedAt` / `sourceID` / `days`；原子写入 |
| 内置快照（源） | `Resources/holiday_snapshot.json` | 打包后位于 App 的 `Contents/Resources/` |
| 图标（源） | `Resources/AppIcon.svg` → `Resources/AppIcon.icns` | |
| 已安装 App | `/Applications/TinCal.app` | 开机自启与菜单栏槽位都依赖此路径 |
| 临时调试日志 | `/tmp/tincal_debug.log` | `StatusBarController.debugLog` 输出面板开关时序，验证后应移除 |

## 官方年份门控

`HolidayStore.officialYears` 是「已官方发布假期安排」的年份白名单，当前为 `[2025, 2026]`。

新增年份时：把年份加入该集合，并同步更新 `Resources/holiday_snapshot.json`；未收录的年份不渲染休 / 班角标，仅按周末判断。
