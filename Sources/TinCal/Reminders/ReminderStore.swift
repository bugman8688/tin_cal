import AppKit
import Combine
import EventKit
import Foundation

/// 提醒事项访问状态（由 `EKAuthorizationStatus` 映射）。
enum ReminderAccessState: Equatable {
    case notDetermined
    case requesting
    case granted
    case denied
    case restricted
    /// 仅可写入、不可读取，对本只读需求等同不可用。
    case writeOnly
    case unknown
}

enum ReminderStoreError: Error {
    case fetchFailed
}

/// 系统「提醒事项」只读数据层：权限状态机 + 拉取快照 + 跨进程变更刷新。
///
/// 明确只读：不做写入 / 编辑 / 完成；管理操作一律跳转系统「提醒事项」App。
@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var accessState: ReminderAccessState
    /// 未完成快照（含已过期项），是 `remindersByDay` 的唯一数据源。
    /// 任何写入都会使分钟桶缓存失效（结构上防止漏写失效导致展示陈旧）。
    @Published private(set) var activeItems: [ReminderItem] = [] {
        didSet { remindersByDayMinuteKey = nil }
    }
    /// 展示快照的分钟桶缓存：同分钟内多处读取结果一致，跨分钟自动失效重算。
    private var remindersByDayMinuteKey: String?
    private var remindersByDayCache: [String: [ReminderItem]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    /// 展示口径：未完成且未过期，按截止日分组。读取时按当前时间重算，
    /// 同一自然分钟内复用缓存（单次渲染多处访问一致），跨分钟自动失效。
    var remindersByDay: [String: [ReminderItem]] {
        let now = Date()
        let minuteKey = Self.minuteBucketKey(for: now)
        if minuteKey != remindersByDayMinuteKey {
            remindersByDayMinuteKey = minuteKey
            remindersByDayCache = ReminderItem.groupByDayKey(
                ReminderItem.filterUnexpired(activeItems, now: now)
            )
        }
        return remindersByDayCache
    }

    private let eventStore = EKEventStore()
    private var hasRequestedAccess = false
    private var refreshTask: Task<Void, Never>?
    private var changeObserver: NSObjectProtocol?
    private var lastRefreshAt: Date?

    init() {
        accessState = Self.mapState(EKEventStore.authorizationStatus(for: .reminder))
        observeStoreChanges()
    }

    deinit {
        refreshTask?.cancel()
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    // MARK: - 查询

    /// 某天的未完成提醒，按提醒时刻升序（无时刻视为 00:00 排最前）。
    func reminders(for dayKey: String) -> [ReminderItem] {
        ReminderItem.sortedByDueTime(remindersByDay[dayKey] ?? [])
    }

    /// 是否可向月历注入提醒标记：仅已授权为真；未授权 / 仅写入等一律不亮。
    var canShowReminders: Bool {
        accessState == .granted
    }

    // MARK: - 权限

    /// 面板打开时调用：未授权则发起系统授权；已授权则按需刷新。
    func requestAccessIfNeeded() async {
        switch accessState {
        case .notDetermined:
            await requestAccess()
        case .granted:
            await refreshIfNeeded()
        default:
            break
        }
    }

    func requestAccess() async {
        guard !hasRequestedAccess, accessState == .notDetermined else { return }
        hasRequestedAccess = true
        accessState = .requesting
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            accessState = granted ? .granted : .denied
            if granted { await fetchReminders() }
        } catch {
            accessState = .denied
            lastError = "授权失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 拉取

    func refreshIfNeeded(force: Bool = false) async {
        guard accessState == .granted else { return }
        if !force, let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < 30 { return }
        await fetchReminders()
    }

    func fetchReminders() async {
        guard accessState == .granted, !isLoading else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let reminders = try await loadReminders()
            let items = reminders.compactMap(snapshot)
            activeItems = ReminderItem.filterActive(items)
            lastRefreshAt = Date()
        } catch {
            lastError = "读取提醒事项失败：\(error.localizedDescription)"
        }
    }

    /// EventKit 仅提供 completion 版查询，这里包装为 async，回调线程不限。
    private func loadReminders() async throws -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: nil)
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: ReminderStoreError.fetchFailed)
                }
            }
        }
    }

    /// 立即快照，不跨线程持有 `EKReminder`。
    private func snapshot(_ reminder: EKReminder) -> ReminderItem? {
        guard let components = reminder.dueDateComponents else { return nil }
        // 时刻按 floating 字段直接算分钟数，不做时区换算；全天（无时分）为 nil。
        let minutes: Int?
        if let hour = components.hour, let minute = components.minute {
            minutes = hour * 60 + minute
        } else {
            minutes = nil
        }
        return ReminderItem.makeSnapshot(
            id: reminder.calendarItemIdentifier,
            title: reminder.title,
            dueDay: MonthGrid.calendar.date(from: components),
            dueMinutes: minutes,
            notes: reminder.notes,
            listName: reminder.calendar.title,
            isCompleted: reminder.isCompleted
        )
    }

    // MARK: - 跳转系统 App / 设置

    /// 打开系统「提醒事项」App：优先按 bundle id 定位（macOS 27 上私有 scheme 可能无处理程序并弹系统报错框）。
    func openRemindersApp() {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            return
        }
        for scheme in ["x-apple-reminders://", "reminders://"] {
            if let url = URL(string: scheme), NSWorkspace.shared.open(url) { return }
        }
    }

    func openPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Reminders",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
            "x-apple.systempreferences:",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }

    // MARK: - 私有

    /// 分钟桶键（Asia/Shanghai 的年月日时分），用于缓存同分钟内一致的展示快照。
    private static func minuteBucketKey(for date: Date) -> String {
        let components = MonthGrid.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            + "-\(components.hour ?? 0)-\(components.minute ?? 0)"
    }

    private static func mapState(_ status: EKAuthorizationStatus) -> ReminderAccessState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .granted
        case .writeOnly: return .writeOnly
        @unknown default: return .unknown
        }
    }

    private func observeStoreChanges() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, accessState == .granted else { return }
                scheduleRefresh()
            }
        }
    }

    /// 用户切出去改了提醒事项再回来：1s 节流刷新，避免连续通知抖动。
    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await fetchReminders()
        }
    }
}
