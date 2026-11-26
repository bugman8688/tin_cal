import Foundation

/// 月历中的单个格子。
struct MonthDay: Identifiable {
    /// `yyyy-MM-dd`（Asia/Shanghai 口径）。
    let id: String
    let date: Date
    let dayNumber: Int
    let isInMonth: Bool
    let isToday: Bool
}

/// 公历月历网格计算。周日为每周第一天。
enum MonthGrid {
    private static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    /// 共享日历（Asia/Shanghai，公历，周日起始）。时区口径的唯一事实源，提醒事项模块复用。
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 1
        return calendar
    }()

    /// 返回覆盖整月的完整周网格（4–6 行），含月初前、月末后的补位日期。
    static func days(for anchor: Date, today: Date = Date()) -> [MonthDay] {
        guard let monthStart = startOfMonth(for: anchor),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        // weekday：1 = 周日，与 firstWeekday = 1 对齐。
        let leading = calendar.component(.weekday, from: monthStart) - 1
        let rowCount = (leading + dayRange.count + 6) / 7
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else {
            return []
        }

        return (0..<(rowCount * 7)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            return MonthDay(
                id: key(for: date),
                date: date,
                dayNumber: calendar.component(.day, from: date),
                isInMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    /// 如「2026 / 11」。
    static func monthTitle(for anchor: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: anchor)
        return "\(components.year ?? 0) / \(components.month ?? 0)"
    }

    /// 翻月：结果锚定到目标月 1 日 00:00（Asia/Shanghai）。
    static func addingMonths(_ value: Int, to anchor: Date) -> Date {
        guard let monthStart = startOfMonth(for: anchor) else { return anchor }
        return calendar.date(byAdding: .month, value: value, to: monthStart) ?? monthStart
    }

    // MARK: - 私有

    private static func startOfMonth(for date: Date) -> Date? {
        calendar.dateInterval(of: .month, for: date)?.start
    }

    /// 日期键 `yyyy-MM-dd`（Asia/Shanghai）。提醒事项模块复用此口径，避免两处漂移。
    static func key(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            preconditionFailure("无效日期组件：\(date)")
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
