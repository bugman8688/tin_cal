import Combine
import Foundation
import ServiceManagement

/// 开机自启管理：基于 `SMAppService.mainApp`，只做状态读取和用户触发的注册/注销。
@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var lastError: String?

    /// 开机自启要求 App 位于 /Applications，否则系统会拒绝注册。
    var isInApplicationsFolder: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            lastError = enabled
                ? "注册登录项失败：\(error.localizedDescription)"
                : "取消登录项失败：\(error.localizedDescription)"
            refreshStatus()
        }
    }
}
