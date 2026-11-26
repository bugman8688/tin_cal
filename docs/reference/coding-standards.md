# 编码规范

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：Swift 约定与命名/日期口径 | hanbing | 2026-11-26 |

## 语言与工具链

- Swift 5 语言模式（`Package.swift` 中 `swiftLanguageMode(.v5)`），最低 macOS 14。
- 只用 Swift Package + 命令行脚本，**不引入 `.xcodeproj`**（本机无 Xcode，工程文件不可维护）。
- UI 用 SwiftUI 声明式写法；菜单栏与窗口托管的 AppKit 部分保持最小。

## 日期与时区

| 约定 | 说明 |
| --- | --- |
| 所有日期换算走 `MonthGrid.calendar` | 公历 + `Asia/Shanghai`，是项目内时区口径的唯一事实源 |
| 禁止 `Calendar.current` / 依赖系统时区 | 换机器、改时区都会导致日期归属漂移 |
| 日期键统一 `yyyy-MM-dd` | 用 `MonthGrid.key(for:)`，节假日与提醒事项共用 |
| 时刻用「当日分钟数」而非 `Date` | 如 `dueMinutes`，floating 语义，规避时区与 DST 抖动 |
| 农历只用 `Calendar(identifier: .chinese)` | 中文日 / 月名必须自己映射，`DateFormatter` 会产出「十月16」混排 |
| 节气按太阳黄经计算 | 禁止硬编码日期表 |

## 类型与分层

- 数据层用 `@MainActor final class XxxStore: ObservableObject`，通过 `@Published private(set)` 暴露只读状态。
- 跨线程传递的数据一律先转成值类型快照（如 `ReminderItem`），**不跨线程持有 EventKit 对象**。
- 纯逻辑（筛选、分组、排序、日期键、命中判定）写成 `static` 函数且不依赖 AppKit，便于单测。
- 消费层不允许各自实现过滤逻辑：展示口径只在 Store 的派生属性里定义一次，多出口共用。

## 命名

| 场景 | 约定 | 示例 |
| --- | --- | --- |
| Store | `XxxStore` | `HolidayStore`、`ReminderStore` |
| 值类型快照 | 业务名词，不带 `DTO` / `Model` 后缀 | `ReminderItem`、`HolidayDay` |
| 纯函数 | 动词开头，语义完整 | `filterActive`、`filterUnexpired`、`groupByDayKey` |
| 日期键参数 | `dayKey` | `reminders(for dayKey: String)` |
| 设置项键 | `settings.xxx` | `settings.use24Hour` |

## 注释

- 用中文，解释**为什么**这么写、边界是什么；不复述代码在做什么。
- 涉及「不这样写会出错」的地方必须写明后果（例如 `Calendar.current` 会导致归属漂移）。
- 被刻意放弃的方案（如不做定时刷新）应在注释或 ADR 里留痕，避免后人当 bug 修。

## 网络与数据

- `URLSession` 显式设 10s 请求超时、20s 资源超时。
- 超时、HTTP 错误、解析失败分开上报，不要统一吞成「网络错误」。
- 任何数据链路都要有兜底，不得因拉取失败返回空数据导致界面空白。
- 缓存写入用原子替换（临时文件 + `replaceItemAt`）。

## 测试

- 框架 `swift-testing`：`@Test` + `#expect`，位于 `Tests/TinCalTests/`。
- 日期用例固定用 `Asia/Shanghai` 构造输入，不依赖运行环境时区。
- 优先覆盖纯函数与边界（跨日、UTC 边界、空输入），UI 与 EventKit 走真机验证。
- 命令统一 `./scripts/test.sh`，不要直接 `swift test`。

## 禁止项

- 禁止用 `xcodebuild`（CLT 下不可用）。
- 禁止在菜单栏 label 使用 SwiftUI `TimelineView(.periodic)`（macOS 27 会卡死主线程）。
- 禁止从 `dist/` 直接启动做运行验证（菜单栏项会异常），必须装到 `/Applications`。
- 禁止提交临时调试日志（如 `/tmp/tincal_debug.log` 相关代码应在验证完成后移除）。
- 禁止把密码、密钥、内部 IP、手机号写入代码、文档或提交信息。
