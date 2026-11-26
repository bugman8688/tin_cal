import Foundation

/// 系统「提醒事项」的只读值类型快照。
///
/// 定位是**一次性提醒**：只保留归属到某一天所需的最小信息 + 同日排序所需的时刻。
/// 已拍板的裁剪项：不含优先级、不含列表颜色；时刻不落成 `Date`，仅保留分钟数
/// （见 `dueMinutes`）。
/// 由 `ReminderStore` 从 EventKit 映射而来，避免跨线程持有 `EKReminder`。
struct ReminderItem: Identifiable, Equatable, Sendable {
    /// `EKReminder.calendarItemIdentifier`，用于唯一标识与后续跳转。
    /// 若将来展开重复提醒的多天 occurrence，需改为带日期后缀，否则 id 冲突。
    let id: String
    let title: String
    /// 截止日（已归一到上海当日 00:00），仅用于归属到月历中的某一天。
    ///
    /// 等值为**全字段快照一致**，不用于身份判定；UI 选中态请以 `id` 为准，
    /// 否则 Store 刷新后同 id 的不同快照会导致详情页被意外重置。
    let dueDay: Date
    /// 提醒时刻的「当日分钟数」（`hour * 60 + minute`），仅用于同日升序排序；nil 表示无具体时刻（全天）。
    ///
    /// 直接取自 `EKReminder.dueDateComponents` 的 hour/minute 字段，**不经过 Calendar → Date**
    /// （floating 语义）：用户切换时区后该值不变，与「只关心哪一天」的口径一致，同时规避 DST 抖动。
    let dueMinutes: Int?
    /// 备注（可空；空串已归一为 nil）。
    let notes: String?
    /// 所属提醒事项列表名（可空；空串已归一为 nil）。
    let listName: String?
    let isCompleted: Bool

    // MARK: - 纯逻辑（不依赖 EventKit，便于单测）

    /// 由源数据构造快照；无截止日期时返回 nil（该提醒不出现在任何日期下）。
    ///
    /// ⚠️ 本函数**不做完成态筛选**（`isCompleted` 原样保留）；「仅未完成」口径由
    /// `filterActive` 负责，接入层必须两者配合使用。
    ///
    /// 时刻信息仅以 `dueMinutes` 保留：`dueDay` 一律归一到当日 00:00
    /// （归属口径不变），排序用的分钟数由调用方从原始 `DateComponents` 直接算出后传入。
    static func makeSnapshot(
        id: String,
        title: String,
        dueDay: Date?,
        dueMinutes: Int? = nil,
        notes: String? = nil,
        listName: String? = nil,
        isCompleted: Bool
    ) -> ReminderItem? {
        guard let dueDay else { return nil }
        return ReminderItem(
            id: id,
            title: title,
            dueDay: MonthGrid.calendar.startOfDay(for: dueDay),
            dueMinutes: dueMinutes,
            notes: Self.normalized(notes),
            listName: Self.normalized(listName),
            isCompleted: isCompleted
        )
    }

    /// 同日排序：按提醒时刻升序；无时刻（全天）视为 00:00 排最前，同刻依次用标题、`id` 兜底
    /// （标题按 Unicode 码点序、不引入本地化依赖，保证任何环境下顺序一致且可测）。
    ///
    /// 排序只发生在消费出口（`ReminderStore.reminders(for:)`），分组与归属链路不受影响。
    static func sortedByDueTime(_ items: [ReminderItem]) -> [ReminderItem] {
        items.sorted {
            ($0.dueMinutes ?? -1, $0.title, $0.id) < ($1.dueMinutes ?? -1, $1.title, $1.id)
        }
    }

    /// 仅保留未完成的提醒。**在消费快照前调用**，与 `makeSnapshot` 共同构成「未完成」口径。
    static func filterActive(_ items: [ReminderItem]) -> [ReminderItem] {
        items.filter { !$0.isCompleted }
    }

    /// 是否已过期（过期即不再展示）。
    ///
    /// 口径：到期日早于今日 → 过期；晚于今日 → 未过期；等于今日时，无具体时刻（全天）
    /// 保留，有时刻则当前上海分钟数**严格大于** `dueMinutes` 才过期（等号保留，提醒当分钟仍显示）。
    static func isExpired(
        _ item: ReminderItem,
        now: Date,
        calendar: Calendar = MonthGrid.calendar
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        if item.dueDay < today { return true }
        if item.dueDay > today { return false }
        guard let dueMinutes = item.dueMinutes else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return nowMinutes > dueMinutes
    }

    /// 剔除已过期项；与 `filterActive` 配合构成「未完成且未过期」的展示口径。
    static func filterUnexpired(
        _ items: [ReminderItem],
        now: Date,
        calendar: Calendar = MonthGrid.calendar
    ) -> [ReminderItem] {
        items.filter { !isExpired($0, now: now, calendar: calendar) }
    }

    /// 按截止日分组为 `yyyy-MM-dd` 键。
    ///
    /// 字典本身无序（同键内数组保序）；UI 若需按日期遍历，请自行排序。
    static func groupByDayKey(_ items: [ReminderItem]) -> [String: [ReminderItem]] {
        Dictionary(grouping: items, by: { Self.dayKey(for: $0.dueDay) })
    }

    /// 日期键直接复用 `MonthGrid.key(for:)`，保证与月历同一口径，避免归属错位。
    static func dayKey(for date: Date) -> String {
        MonthGrid.key(for: date)
    }

    private static func normalized(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
