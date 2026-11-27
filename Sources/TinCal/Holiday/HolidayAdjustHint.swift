import Foundation

/// 调休提示：延展区标题栏内跟在「M月d日 星期X」之后的一段着色文案。
///
/// 纯函数承载文案与语义类别，配色由视图层映射（沿用 `DayCell.badge` 语义）：
/// 放假 → 蓝（`PanelPalette.offDayBadge`），补班 → 红橙（`PanelPalette.workDayBadge`）。
struct HolidayAdjustHint: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 放假（法定节假日 + 调休）。
        case offDay
        /// 补班（周末上班）。
        case workDay
    }

    /// 形如「(国庆节，休息)」，整段使用同一颜色。
    let text: String
    let kind: Kind

    /// - Parameters:
    ///   - name: `HolidayStore.name(for:)` 提供的节日名；空白时退化为不含主语的「(休息)/(上班)」。
    ///   - isOffDay: `HolidayDay.isOffDay`，`true` 为放假、`false` 为补班。
    static func make(name: String?, isOffDay: Bool) -> HolidayAdjustHint {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = trimmed.isEmpty ? "" : "\(trimmed)，"
        let action = isOffDay ? "休息" : "上班"
        return HolidayAdjustHint(
            text: "(\(subject)\(action))",
            kind: isOffDay ? .offDay : .workDay
        )
    }
}
