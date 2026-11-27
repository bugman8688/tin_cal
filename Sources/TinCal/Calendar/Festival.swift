import Foundation

/// 常见节日（非法定）规则与名称。展示名一律用中文简称，避免副标题小字过长。
struct Festival: Equatable, Sendable {
    enum Rule: Equatable, Sendable {
        /// 公历固定日期。
        case solar(month: Int, day: Int)
        /// 农历固定日期，排除闰月。
        case lunar(month: Int, day: Int)
        /// 除夕：次日为农历正月初一（兼容腊月大小月）。
        case lunarNewYearEve
        /// 某月第 `nth` 个指定星期几。`weekday` 取 Calendar 语义：1=周日、2=周一 … 5=周四。
        case nthWeekday(month: Int, weekday: Int, nth: Int)
    }

    let id: String
    let name: String
    let rule: Rule
}

/// 本地静态节日目录，无网络、无授权、无缓存。
///
/// 收录传统农历节 + 公历纪念/大节（不含纯娱乐化的愚人节、万圣节、平安夜、感恩节）。
enum FestivalCatalog {
    /// 数组顺序即同日冲突时的优先级：农历 → 公历固定 → 月日序数，首个命中即返回。
    static let all: [Festival] = [
        // 农历
        Festival(id: "lantern", name: "元宵", rule: .lunar(month: 1, day: 15)),
        Festival(id: "qixi", name: "七夕", rule: .lunar(month: 7, day: 7)),
        Festival(id: "ghost", name: "中元", rule: .lunar(month: 7, day: 15)),
        Festival(id: "chongyang", name: "重阳", rule: .lunar(month: 9, day: 9)),
        Festival(id: "laba", name: "腊八", rule: .lunar(month: 12, day: 8)),
        Festival(id: "newYearsEve", name: "除夕", rule: .lunarNewYearEve),

        // 公历固定
        Festival(id: "valentines", name: "情人节", rule: .solar(month: 2, day: 14)),
        Festival(id: "womensDay", name: "妇女节", rule: .solar(month: 3, day: 8)),
        Festival(id: "arborDay", name: "植树节", rule: .solar(month: 3, day: 12)),
        Festival(id: "youthDay", name: "青年节", rule: .solar(month: 5, day: 4)),
        Festival(id: "childrensDay", name: "儿童节", rule: .solar(month: 6, day: 1)),
        Festival(id: "partyDay", name: "建党节", rule: .solar(month: 7, day: 1)),
        Festival(id: "armyDay", name: "建军节", rule: .solar(month: 8, day: 1)),
        Festival(id: "teachersDay", name: "教师节", rule: .solar(month: 9, day: 10)),
        Festival(id: "christmas", name: "圣诞节", rule: .solar(month: 12, day: 25)),

        // 月日序数
        Festival(id: "mothersDay", name: "母亲节", rule: .nthWeekday(month: 5, weekday: 1, nth: 2)),
    ]

    /// 当日节日名（简称）；无节日返回 nil。农历判定全部复用 `LunarCalendar`（`.chinese` + Asia/Shanghai）。
    static func name(for date: Date) -> String? {
        all.first { matches($0.rule, date) }?.name
    }

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    private static func matches(_ rule: Festival.Rule, _ date: Date) -> Bool {
        switch rule {
        case let .solar(month, day):
            let components = gregorian.dateComponents([.month, .day], from: date)
            return components.month == month && components.day == day

        case let .lunar(month, day):
            let lunar = LunarCalendar.components(for: date)
            return lunar.month == month && lunar.day == day && !lunar.isLeap

        case .lunarNewYearEve:
            guard let next = gregorian.date(byAdding: .day, value: 1, to: date) else { return false }
            let lunar = LunarCalendar.components(for: next)
            return lunar.month == 1 && lunar.day == 1 && !lunar.isLeap

        case let .nthWeekday(month, weekday, nth):
            let components = gregorian.dateComponents([.month, .weekday, .day], from: date)
            guard components.month == month,
                  components.weekday == weekday,
                  let day = components.day else {
                return false
            }
            return (day - 1) / 7 + 1 == nth
        }
    }
}
