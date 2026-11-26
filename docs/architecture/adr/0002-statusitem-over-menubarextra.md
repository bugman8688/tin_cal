# ADR-0002：菜单栏用 NSStatusItem 而非 MenuBarExtra

- 状态：已采纳
- 日期：2026-11-26

## 背景（Context）

需求是菜单栏常驻显示实时时间（精确到分钟，可选到秒）。SwiftUI 的 `MenuBarExtra` 是声明式首选方案，配合 `TimelineView(.periodic)` 即可按周期刷新 label。

实测在 macOS 27 上，`MenuBarExtra` 的 label 使用 `TimelineView(.periodic)` 会导致主线程 runloop 被卡死：`DispatchQueue.main.asyncAfter`、`Task` 的 continuation 全部不再恢复，整个 App 表现为假死。

## 决策（Decision）

菜单栏部分退回 AppKit：

- 用 `NSStatusItem` + `NSTimer`（1 秒间隔，加入 `.common` runloop mode，保证菜单跟踪与滚动期间也继续刷新）驱动标题文本。
- 面板仍然是 SwiftUI（`CalendarPanel`），通过 `NSHostingController` 装进 `NSPopover`。
- `NSPopover` 使用 `.applicationDefined` 行为，关闭时机自己完全掌控（配合外部点击监听实现「点面板外关闭」）。

## 备选方案（Alternatives）

1. **`MenuBarExtra` + `TimelineView(.periodic)`**
   - 放弃原因：macOS 27 下卡死主线程，见上。
2. **`MenuBarExtra` + `Timer` 手动驱动状态**
   - 放弃原因：label 内容仍走 SwiftUI 更新路径，无法确认规避同一问题；且 `MenuBarExtra` 对弹出样式的控制力弱于 `NSPopover`。
3. **纯 AppKit 写整个面板**
   - 放弃原因：月历、农历、角标的布局与状态管理用 SwiftUI 明显更省代码，没必要。

## 后果（Consequences）

正面：

- 菜单栏时间刷新稳定，主线程不再被卡住。
- 弹出行为（外部点击关闭、不受 transient 抢先关闭影响）完全可控。
- 面板仍享有 SwiftUI 的开发效率。

代价与边界：

- 菜单栏部分与面板部分是两种技术栈，新人 / AI 容易误把菜单栏改回 `MenuBarExtra`。
- 菜单栏标题只能用 `NSStatusBarButton` 的文本与字体 API，富文本样式受限。
- 每秒刷新文本属于轻量操作，但**不要**在 timer 回调里做数据抓取或重计算。
- 任何「用 SwiftUI 定时视图刷新菜单栏」的改造都必须先在真机确认不卡死，否则一律禁止。
