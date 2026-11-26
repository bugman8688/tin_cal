import Foundation

/// 农历（中国历）日期换算与中文名。
enum LunarCalendar {
    private static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = timeZone
        return calendar
    }()

    private static let monthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]

    private static let dayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    /// 农历月、日（1 起）及是否闰月。
    static func components(for date: Date) -> (month: Int, day: Int, isLeap: Bool) {
        let components = calendar.dateComponents([.month, .day], from: date)
        return (
            month: components.month ?? 1,
            day: components.day ?? 1,
            isLeap: components.isLeapMonth ?? false
        )
    }

    /// 农历完整名称，如「十月十六」「闰六月初一」。
    static func fullText(for date: Date) -> String {
        let lunar = components(for: date)
        return monthName(lunar.month, isLeap: lunar.isLeap) + dayName(lunar.day)
    }

    /// 月历格子用短标签：初一显示月名，其余显示日名。
    static func dayLabel(for date: Date) -> String {
        let lunar = components(for: date)
        return lunar.day == 1
            ? monthName(lunar.month, isLeap: lunar.isLeap)
            : dayName(lunar.day)
    }

    private static func monthName(_ month: Int, isLeap: Bool) -> String {
        guard monthNames.indices.contains(month - 1) else { return "" }
        return (isLeap ? "闰" : "") + monthNames[month - 1]
    }

    private static func dayName(_ day: Int) -> String {
        guard dayNames.indices.contains(day - 1) else { return "" }
        return dayNames[day - 1]
    }
}
