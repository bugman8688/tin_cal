# 架构总览

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：模块职责与数据流 | hanbing | 2026-11-26 |

## 一句话

macOS 菜单栏常驻的小工具：菜单栏显示「月日 周几 时间」，点击展开一个月历面板，面板内含农历、24 节气、大陆放假 / 补班标记，以及当天的未完成待办。

## 技术形态

| 项 | 选择 | 原因 |
| --- | --- | --- |
| 进程生命周期 | 纯 AppKit（`main.swift` + `AppDelegate`） | 避免 SwiftUI `App` 场景自动弹出空窗口 |
| 菜单栏 | `NSStatusItem` + `Timer` 每秒刷新文本 | `MenuBarExtra` 的 label 用 `TimelineView(.periodic)` 在 macOS 27 会卡死主线程，见 [ADR-0002](adr/0002-statusitem-over-menubarextra.md) |
| 面板 | SwiftUI 视图 + `NSHostingController` + `NSPopover` | UI 迭代快，同时保留 AppKit 对弹出行为的完全控制 |
| 构建 | Swift Package + 命令行脚本 | 机器只有 Command Line Tools，无 Xcode，工程文件不可维护 |
| Bundle | `local.hanbing.tincal`，`LSUIElement=true` | 菜单栏工具，不显示 Dock 图标 |

## 模块职责

```plaintext
AppDelegate
 ├── SettingsStore        时间格式 / 周几 / 秒 / 节假日主源（UserDefaults）
 ├── HolidayStore         节假日数据：主源 → 备源 → 本地缓存 → 内置快照
 ├── LoginItemManager     开机自启（SMAppService.mainApp）
 └── StatusBarController  菜单栏项 + 面板 + 手势 + 定时刷新
      └── ReminderStore   提醒事项只读接入（EventKit）
           └── ReminderItem 值类型快照 + 纯函数（筛选 / 分组 / 过期 / 排序）
```

| 模块 | 职责 | 不负责 |
| --- | --- | --- |
| `StatusBarController` | 菜单栏项、popover 开合、外部点击关闭、横滑翻月、1s 时间刷新 | 任何业务数据 |
| `CalendarPanel` | 面板布局、展开判断、把提醒灯泡注入 `DayCell` | 数据抓取 |
| `MonthGrid` | 月历网格、日期键、共享 `Calendar`（时区唯一事实源） | 农历 / 节气 |
| `LunarCalendar` / `SolarTerm` | 农历换算与中文名 / 24 节气 | 界面 |
| `HolidayStore` | 数据降级链路、官方年份门控、状态上报 | 角标绘制 |
| `ReminderStore` | 权限状态机、EventKit 拉取、变更监听、展示口径 | 写入 / 编辑提醒 |
| `SettingsStore` | 配置持久化与时间格式化 | 界面控件 |

## 关键数据流

### 节假日

```plaintext
App 启动
 └─ HolidayStore.init
     └─ 先加载内置快照（保证任何情况下都有数据）
          ↓
     AppDelegate 后台 Task → refresh(primarySourceID:)
          ├─ 主源成功 → 写缓存 + 更新状态
          ├─ 主源失败 → 备源
          ├─ 备源失败 → 本地缓存
          └─ 全部失败 → 保留内置快照，状态栏标注原因
```

任何分支都不允许返回空数据，否则月历会丢失休 / 班标记。详见 [ADR-0003](adr/0003-holiday-fallback-chain.md)。

### 提醒事项

```plaintext
面板打开
 └─ ReminderStore.requestAccessIfNeeded()
     ├─ .notDetermined → 系统授权
     ├─ .granted       → refreshIfNeeded()（30s 节流）
     └─ 其它           → 列表区显示引导卡

点某一天（展开）
 └─ refreshIfNeeded(force: true)（跳过 30s 节流）

fetchReminders()
 └─ EKEventStore.fetchReminders(in: nil)
     → 立即快照为 ReminderItem（不跨线程持有 EKReminder）
     → filterActive（未完成）
     → 存入 activeItems（@Published）
          ↓
     remindersByDay（计算属性）
       = filterUnexpired(now) → groupByDayKey
       （分钟桶缓存，数据写入即失效）
          ↓
     ├─ 底部列表：reminders(for: dayKey) → sortedByDueTime
     └─ 月历灯泡：remindersByDay.keys 注入 DayCell.hasReminder

EKEventStoreChanged 通知 → 1s 节流 → fetchReminders()
```

两条出口共用同一个 `remindersByDay`，避免「灯泡亮着但列表为空」的分叉。

## 统一口径

| 口径 | 事实源 | 说明 |
| --- | --- | --- |
| 时区 / 日期 | `MonthGrid.calendar`（公历 + Asia/Shanghai） | 全项目唯一，禁止 `Calendar.current` |
| 日期键 | `MonthGrid.key(for:)` → `yyyy-MM-dd` | 节假日与提醒事项复用 |
| 提醒时刻 | `dueMinutes`（当日分钟数，floating） | 不落 `Date`，切换时区不变 |
| 农历 | `Calendar(identifier: .chinese)` | 中文日 / 月名自行映射 |
| 节气 | 太阳黄经计算 | 禁止固定日期表 |

## 已固化的设计决策

| 决策 | 记录 |
| --- | --- |
| 提醒事项只读接入 + 过期过滤口径 | [ADR-0001](adr/0001-reminders-readonly-and-expiry.md) |
| 菜单栏用 NSStatusItem 而非 MenuBarExtra | [ADR-0002](adr/0002-statusitem-over-menubarextra.md) |
| 节假日四级降级链路 | [ADR-0003](adr/0003-holiday-fallback-chain.md) |
