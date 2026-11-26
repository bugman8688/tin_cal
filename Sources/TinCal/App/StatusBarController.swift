import AppKit
import SwiftUI

/// 状态栏点击命中判定（纯几何，抽出以便单测）。
enum StatusBarHitTest {
    /// 父视图坐标系下的 `point` 是否落在 `buttonFrame`（同坐标系）内。
    ///
    /// 边界语义与 `NSRect.contains` 一致：左/下边界含，右/上边界不含。
    static func contains(pointInSuperview point: NSPoint, buttonFrame: NSRect) -> Bool {
        buttonFrame.contains(point)
    }
}

/// 菜单栏控制器：AppKit `NSStatusItem` + `Timer` 驱动时间文本，面板仍用 SwiftUI。
///
/// macOS 27 下 `MenuBarExtra` 的 label 使用 `TimelineView(.periodic)` 会卡死主线程，
/// 因此菜单栏改由 AppKit 直接管理。
@MainActor
final class StatusBarController: NSObject {
    private let settings: SettingsStore
    private let holidays: HolidayStore
    private let loginItem: LoginItemManager

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let panelState = CalendarViewState()
    /// 生命周期与 controller 一致：不随 popover 重建，权限状态与缓存得以保留。
    private let reminderStore = ReminderStore()
    private var timer: Timer?
    private var settingsWindow: NSWindow?
    private var scrollMonitor: Any?
    private var scrollSettleWork: DispatchWorkItem?
    private var isAnimatingPage = false
    /// 面板外部点击监听（`.applicationDefined` 不会自动关闭，需自行管理）。
    private var outsideLocalMonitor: Any?
    private var outsideGlobalMonitor: Any?

    /// 翻页位移阈值（pt）：跟手滑过该值即提前切标题，松手后越过该值即翻页。
    private let pageTurnThreshold: CGFloat = 60

    init(settings: SettingsStore, holidays: HolidayStore, loginItem: LoginItemManager) {
        self.settings = settings
        self.holidays = holidays
        self.loginItem = loginItem
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configurePopover()
        startScrollMonitor()
        startTimer()
        updateTitle()
    }

    // MARK: - 生命周期

    /// 停止计时器并移除状态栏项，避免泄漏。
    func invalidate() {
        timer?.invalidate()
        timer = nil
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        stopOutsideClickMonitors()
        scrollSettleWork?.cancel()
        popover.performClose(nil)
        settingsWindow?.close()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - 状态栏项

    private func configureButton() {
        guard let button = statusItem.button else { return }
        // 菜单栏只显示时间，不显示图标。
        button.image = nil
        button.imagePosition = .noImage
        // 与系统菜单栏一致的字号，数字等宽避免时间跳动。
        let menuBarSize = NSFont.menuBarFont(ofSize: 0).pointSize
        button.font = NSFont.monospacedDigitSystemFont(
            ofSize: menuBarSize > 0 ? menuBarSize : 13,
            weight: .regular
        )
        button.target = self
        button.action = #selector(handleClick)
        // 左键在 mouseDown 开合面板：关闭后立即再点不会被上一事件的残留状态吞掉。
        // 右键保持 mouseUp 弹菜单：`NSStatusBarButton` 对 rightMouseDown 会先被菜单栏
        // 截获（未设 menu 时 action 收不到），沿用已验证可用的 mouseUp 路径。
        button.sendAction(on: [.leftMouseDown, .rightMouseUp])
    }

    @objc private func handleClick() {
        debugLog("[click] type=\(NSApp.currentEvent?.type.rawValue ?? 0)")
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        // 右键或 Ctrl+左键弹菜单，其余一律开关面板。toggle 本身幂等，无需时间窗抑制。
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "设置", action: #selector(openSettingsAction), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "关于", action: #selector(showAboutAction), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 TinCal", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func openSettingsAction() {
        showSettings()
    }

    @objc private func showAboutAction() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func startTimer() {
        let timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        // 菜单跟踪 / 滚动等事件期间也要继续刷新。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func tick() {
        updateTitle()
    }

    private func updateTitle() {
        statusItem.button?.title = settings.timeText(for: Date())
    }

    // MARK: - 弹出面板

    private func configurePopover() {
        // `.applicationDefined`：关闭时机完全由我们掌控，避免 `.transient`
        // 在点击锚点按钮时抢先关闭、导致「再点一次又展开」。
        popover.behavior = .applicationDefined
        popover.animates = false
        // 面板为深色设计，popover 边框/箭头也统一深色。
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = makePanelController()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidClose),
            name: NSPopover.didCloseNotification,
            object: popover
        )
    }

    @objc private func popoverDidClose(_ note: Notification) {
        debugLog("[didClose]")
        stopOutsideClickMonitors()
    }

    private func makePanelController() -> NSHostingController<some View> {
        let root = CalendarPanel(state: panelState)
            .environmentObject(settings)
            .environmentObject(holidays)
            .environmentObject(reminderStore)

        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = .preferredContentSize
        return controller
    }

    @objc private func togglePopover() {
        debugLog("[toggle] isShown=\(popover.isShown)")
        if popover.isShown {
            popover.performClose(nil)
            stopOutsideClickMonitors()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        debugLog("[show]")
        // 每次打开回到当月；默认不画选中框（仅保留「今天」红圈标记），点击某天才出现选中态。
        panelState.anchor = MonthGrid.addingMonths(0, to: Date())
        panelState.titleAnchor = nil
        panelState.dragOffset = 0
        panelState.selectedDayKey = nil
        panelState.expandedDayKey = nil
        popover.contentViewController = makePanelController()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 面板一开即处理授权：未授权则发起系统弹窗，已授权则按需刷新。
        Task { await reminderStore.requestAccessIfNeeded() }

        startOutsideClickMonitors()
    }

    // MARK: - 面板外部点击关闭

    private func startOutsideClickMonitors() {
        stopOutsideClickMonitors()
        outsideLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
            return event
        }
        outsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
        }
    }

    private func stopOutsideClickMonitors() {
        if let outsideLocalMonitor {
            NSEvent.removeMonitor(outsideLocalMonitor)
            self.outsideLocalMonitor = nil
        }
        if let outsideGlobalMonitor {
            NSEvent.removeMonitor(outsideGlobalMonitor)
            self.outsideGlobalMonitor = nil
        }
    }

    /// 点击面板外部（且不在状态栏按钮上）时关闭；面板内部点击放行。
    ///
    /// 关键：**用屏幕坐标判断点击是否落在状态栏按钮上，不依赖 `event.window` 身份**——
    /// 该 monitor 可能在按钮 action 之后才收到同一次点击，此时 window 归属并不稳定，
    /// 若按 window 排除会漏判，导致「刚展开就被自己关掉」。
    private func handleOutsideClick(_ event: NSEvent) {
        guard popover.isShown else { return }
        if isClickOnStatusItem() { return }
        if let popoverWindow = popover.contentViewController?.view.window, event.window === popoverWindow {
            return
        }
        debugLog("[outsideClick] close")
        popover.performClose(nil)
    }

    /// 当前鼠标位置是否落在状态栏按钮的可点区域内。
    private func isClickOnStatusItem() -> Bool {
        guard let button = statusItem.button,
              let window = button.window,
              let superview = button.superview else { return false }
        let screen = NSEvent.mouseLocation
        let windowPoint = window.convertFromScreen(NSRect(origin: screen, size: .zero)).origin
        let pointInSuperview = superview.convert(windowPoint, from: nil)
        // button.frame 定义在其 superview 坐标系，故此处用 frame 而不是 button 自身的 bounds。
        return StatusBarHitTest.contains(pointInSuperview: pointInSuperview, buttonFrame: button.frame)
    }

    // MARK: - 触控板双指横滑翻月

    private func startScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }
    }

    private func handleScroll(_ event: NSEvent) {
        // 翻页动画期间忽略新的手势，避免状态错乱。
        guard !isAnimatingPage else { return }
        guard popover.isShown,
              let panelWindow = popover.contentViewController?.view.window,
              event.window === panelWindow else {
            resetScroll()
            return
        }

        // 手指离开后的惯性滚动不参与翻页，避免松手后页面继续漂移。
        guard event.momentumPhase.isEmpty else { return }

        // 触控板手指离开：立即吸附，不再等定时器兜底（消除吸附延迟）。
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            scrollSettleWork?.cancel()
            settleScroll()
            return
        }

        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        // 只响应明显的横向滑动。
        guard abs(deltaX) > abs(deltaY) else { return }

        // 跟手：带阻尼累积位移，最多滑出一整页。
        let damped = deltaX * 0.5
        let next = panelState.dragOffset + damped
        let limit = PanelMetrics.pageWidth
        panelState.dragOffset = max(-limit, min(limit, next))
        updateTitleAnchorForDrag()

        // 触控板手势进行中不判定；无相位事件（鼠标滚轮）用短延迟兜底。
        if event.phase.isEmpty {
            scheduleScrollSettle()
        }
    }

    /// 无相位设备（鼠标滚轮）的兜底：停止一小段时间后再判断是否翻页。
    private func scheduleScrollSettle() {
        scrollSettleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.settleScroll()
        }
        scrollSettleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    /// 跟手滑动时，位移一旦越过翻页阈值就提前把标题切到目标月，让标题跟手反馈；回弹/复位时恢复。
    private func updateTitleAnchorForDrag() {
        let offset = panelState.dragOffset
        guard abs(offset) >= pageTurnThreshold else {
            panelState.titleAnchor = nil
            return
        }
        let step = offset < 0 ? 1 : -1
        panelState.titleAnchor = MonthGrid.addingMonths(step, to: panelState.anchor)
    }

    private func settleScroll() {
        guard !isAnimatingPage else { return }

        let offset = panelState.dragOffset
        guard abs(offset) >= pageTurnThreshold else {
            withAnimation(.easeOut(duration: 0.18)) {
                panelState.dragOffset = 0
                panelState.titleAnchor = nil
            }
            return
        }

        // 双指向左滑 → 下个月；向右滑 → 上个月。
        let step = offset < 0 ? 1 : -1
        let pageWidth = PanelMetrics.pageWidth
        let target = MonthGrid.addingMonths(step, to: panelState.anchor)
        isAnimatingPage = true

        // 标题随翻页立即可见，页面同步滑入。
        panelState.titleAnchor = target
        withAnimation(.easeOut(duration: 0.22)) {
            panelState.dragOffset = step > 0 ? -pageWidth : pageWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self else { return }
            self.panelState.anchor = target
            self.panelState.dragOffset = 0
            self.panelState.titleAnchor = nil
            self.panelState.resetSelection()
            self.isAnimatingPage = false
        }
    }

    private func resetScroll() {
        scrollSettleWork?.cancel()
        panelState.dragOffset = 0
        panelState.titleAnchor = nil
    }

    // MARK: - 临时诊断日志（验证后移除）

    private func debugLog(_ message: String) {
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = URL(fileURLWithPath: "/tmp/tincal_debug.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    // MARK: - 设置窗口

    func showSettings() {
        popover.performClose(nil)
        stopOutsideClickMonitors()

        if settingsWindow == nil {
            let root = SettingsView()
                .environmentObject(settings)
                .environmentObject(holidays)
                .environmentObject(loginItem)
                .environmentObject(reminderStore)
            let controller = NSHostingController(rootView: root)
            controller.sizingOptions = .preferredContentSize

            let window = NSWindow(contentViewController: controller)
            window.title = "TinCal 设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false

            let preferred = controller.preferredContentSize
            window.setContentSize(
                preferred.width > 0 && preferred.height > 0
                    ? preferred
                    : NSSize(width: 440, height: 640)
            )
            window.center()
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
