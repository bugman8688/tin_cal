# 开发指南

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：常见改动路径与测试约定 | hanbing | 2026-11-26 |

## 代码结构速查

```plaintext
Sources/TinCal/
├── main.swift                  # NSApplication 启动入口
├── App/
│   ├── AppDelegate.swift       # 组装各 Store，启动后台刷新
│   └── StatusBarController.swift # NSStatusItem + Timer + NSPopover + 手势
├── MenuBar/
│   ├── CalendarPanel.swift     # 面板根视图（月历 + 底部提醒区）
│   └── DayCell.swift           # 单日格子：公历 + 农历 + 节气 + 休班旗标 + 待办灯泡
├── Calendar/
│   ├── MonthGrid.swift         # 月历网格、日期键、共享 Calendar（时区唯一事实源）
│   ├── LunarCalendar.swift     # 农历换算与中文名
│   └── SolarTerm.swift         # 24 节气（按太阳黄经计算）
├── Holiday/
│   ├── HolidayStore.swift      # 四级数据链路 + 状态
│   ├── HolidaySource.swift     # 主源 / 备源定义
│   └── HolidayDay.swift        # 单日休班模型
├── Reminders/
│   ├── ReminderStore.swift     # EventKit 只读接入、权限状态机、刷新
│   ├── ReminderItem.swift      # 值类型快照 + 纯函数（筛选 / 分组 / 过期判定 / 排序）
│   └── ReminderListView.swift  # 底部待办列表
└── Settings/
    ├── SettingsStore.swift     # UserDefaults 配置项
    ├── SettingsView.swift      # 设置窗口
    └── LoginItemManager.swift  # SMAppService 开机自启
```

## 常用命令

| 目的 | 命令 |
| --- | --- |
| 验证能否编译 | `swift build` |
| 跑全部单测 | `./scripts/test.sh` |
| 改完代码装到 /Applications 并重启 | `./scripts/restart.sh` |
| 只重新生成图标 | `./scripts/make-icon.sh` |
| 退出应用 | `killall TinCal` |

> 不要直接 `swift test`：CLT 环境下 TestingMacros 插件路径缺失会失败，`scripts/test.sh` 已处理该路径。

## 改动路径指引

### 改菜单栏时间显示

1. 格式逻辑在 `SettingsStore.timeText(for:)`。
2. 菜单栏刷新由 `StatusBarController` 的 1 秒 `Timer` 驱动（**不要**换成 SwiftUI `TimelineView(.periodic)`，macOS 27 下会卡死主线程）。
3. 新增设置项：`SettingsStore` 加 `@Published` 属性 + `didSet` 持久化，再在 `SettingsView` 加控件。

### 改月历 / 农历 / 节气

1. 日期口径统一走 `MonthGrid.calendar`（公历 + Asia/Shanghai），**禁止 `Calendar.current`**。
2. 农历只用 `Calendar(identifier: .chinese)`，中文日 / 月名自行映射（`DateFormatter` 配中文农历会输出「十月16」这类混排）。
3. 节气必须按太阳黄经计算，**禁止硬编码日期表**。
4. 新增纯逻辑优先写成不依赖 AppKit 的静态函数，方便在 `Tests/TinCalTests` 里直接测。

### 改节假日数据

1. 链路固定为「主源 → 备源 → 本地缓存 → 内置快照」，任何分支都不得返回空数据导致月历无标记。
2. 未官方发布的年份（`HolidayStore.officialYears` 之外的年份）一律不渲染休 / 班角标，只按周末判断；新增年份时手动把年份加进该集合。
3. npmmirror 数据里 `workdays` 是补班（周末要上班），`inLieuDays` 是调休放假，两者不能都当放假。
4. 改完检查 `Resources/holiday_snapshot.json` 是否需要同步更新（它会被 `build.sh` 复制进 App 的 `Contents/Resources/`）。

### 改提醒事项

1. 只读：不写入、不编辑、不完成，管理操作一律跳系统 App。
2. 任何新增的「展示口径」都要同时作用于两条出口——底部列表与月历灯泡，二者必须同源（统一从 `ReminderStore.remindersByDay` 派生）。
3. 过期判定口径见 [ADR-0001](architecture/adr/0001-reminders-readonly-and-expiry.md)，改动前先读。
4. `dueMinutes` 是「当日分钟数」的 floating 语义，不落 `Date`、不做时区换算；新增比较逻辑必须沿用它。

### 改面板 UI

1. 面板高度由 `PanelMetrics` 统一计算，折叠态与展开态两套常量；新增区块要同步这两个值。
2. 面板宽度固定 320pt，提醒区高度固定（内部 `ScrollView`），避免被列表撑破。
3. 横滑翻月与单击选中的手势在 `StatusBarController.handleScroll` 与 `DayCell.onTap`，改动后必须真机验证不误触。
4. 延展区的展开条件只有一个出处：`CalendarPanel.activeDetailDayKey`（有未完成提醒 **或** 选中日为官方调休日）；调休提示文案口径见 `.trae/specs/add-holiday-adjust-hint/spec.md`。

## 测试约定

- 测试框架：`swift-testing`（`@Test` + `#expect`），位于 `Tests/TinCalTests/`。
- 优先测纯函数与纯几何（日期键、农历、节气、节假日解析、提醒筛选 / 排序、命中判定），UI 与 EventKit 走真机验证。
- 新增日期相关用例时固定使用 `Asia/Shanghai` 时区构造时间，不要依赖运行机器的本地时区。
- 当前基线：101 个用例全绿。

## 验证清单（改完代码后）

1. `swift build` 通过。
2. `./scripts/test.sh` 全绿。
3. `./scripts/restart.sh` 后确认菜单栏时间正常、面板能开合、改动点按预期表现。
4. 涉及提醒事项或权限的改动，必须真机点开面板验证，不能只看编译通过。
