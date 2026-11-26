# 变更日志（CHANGELOG）

记录 tin_cal 项目的重要变更，最新版本在最上。

## 变更总览

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v0.1.0 | 首次公开释放：macOS 菜单栏日历 TinCal | hanbing | 2026-11-26 |

## [2026-11-26] 首次公开释放：macOS 菜单栏日历 TinCal

### 变更内容
- 菜单栏：NSStatusItem + SwiftUI NSPopover 面板，日历图标与实时时间
- 月历：公历网格、农历、24 节气（按太阳黄经计算）
- 节假日：主源 → 备源 → 本地缓存 → 内置快照链路，标注大陆放假 / 补班；未发布年份只按周末判断
- 提醒事项：EventKit 只读接入，底部列表与月历灯泡同源（ReminderStore.remindersByDay）
- 设置页：节假日数据源状态与失败原因展示、开机自启（SMAppService）
- 工程：Swift Package 纯命令行脚本（build / test / restart / make-icon），Info.plist 含 LSUIElement
- 文档：docs 四分类与 ADR、getting-started / development-guide / deployment / reference
- 测试：Tests/TinCalTests 覆盖农历、节气、月历网格、提醒过期口径、设置项
