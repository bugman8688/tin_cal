import Foundation

/// 大陆法定节假日「正日子」判定。
///
/// 快照数据把整个放假区间都标成同一个名字（如 2026-02-15～02-23 全为「春节」），
/// 逐日直出会顶掉同一天的真实节日（如 2/16 除夕）。仅当存储名对应的节日在该日是
/// 「正日子」时才展示该名字，其余假期日由静态节日表或农历接手。
enum LegalHoliday {
    static func isMainDay(name: String, date: Date) -> Bool {
        // 一次性纪念日（如 2015 年抗战胜利 70 周年）没有固定锚点，按展示处理。
        if name.contains("纪念日") { return true }
        if name.contains("元旦") { return isSolar(month: 1, day: 1, date) }
        if name.contains("春节") { return isLunar(month: 1, day: 1, date) }
        if name.contains("清明") { return SolarTerm.name(for: date) == "清明" }
        if name.contains("劳动节") { return isSolar(month: 5, day: 1, date) }
        if name.contains("端午") { return isLunar(month: 5, day: 5, date) }
        if name.contains("中秋") { return isLunar(month: 8, day: 15, date) }
        if name.contains("国庆") { return isSolar(month: 10, day: 1, date) }
        // 未收录的节名保守展示，避免新增节日后静默消失。
        return true
    }

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private static func isSolar(month: Int, day: Int, _ date: Date) -> Bool {
        let components = gregorian.dateComponents([.month, .day], from: date)
        return components.month == month && components.day == day
    }

    private static func isLunar(month: Int, day: Int, _ date: Date) -> Bool {
        let lunar = LunarCalendar.components(for: date)
        return lunar.month == month && lunar.day == day && !lunar.isLeap
    }
}
