import AppKit

/// 应用入口：纯 AppKit 生命周期，避免 SwiftUI 场景自动弹出空窗口。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore?
    private var holidays: HolidayStore?
    private var loginItem: LoginItemManager?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = SettingsStore()
        let holidays = HolidayStore()
        let loginItem = LoginItemManager()

        self.settings = settings
        self.holidays = holidays
        self.loginItem = loginItem

        statusBar = StatusBarController(
            settings: settings,
            holidays: holidays,
            loginItem: loginItem
        )

        // 启动时后台刷新一次节假日数据，失败也不阻塞界面。
        Task {
            await holidays.refresh(primarySourceID: settings.primarySourceID)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBar?.invalidate()
    }
}
