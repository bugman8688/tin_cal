import Foundation
import Testing
@testable import TinCal

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

private let gregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = shanghai
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

private func dayKey(_ date: Date) -> String {
    let components = gregorian.dateComponents([.year, .month, .day], from: date)
    return String(
        format: "%04d-%02d-%02d",
        components.year!,
        components.month!,
        components.day!
    )
}

@Test func solarTerms2026() {
    let expected: [(index: Int, name: String, month: Int, day: Int)] = [
        (0, "小寒", 1, 5), (1, "大寒", 1, 20), (2, "立春", 2, 4), (3, "雨水", 2, 18),
        (4, "惊蛰", 3, 5), (5, "春分", 3, 20), (6, "清明", 4, 5), (7, "谷雨", 4, 20),
        (8, "立夏", 5, 5), (9, "小满", 5, 21), (10, "芒种", 6, 5), (11, "夏至", 6, 21),
        (12, "小暑", 7, 7), (13, "大暑", 7, 23), (14, "立秋", 8, 7), (15, "处暑", 8, 23),
        (16, "白露", 9, 7), (17, "秋分", 9, 23), (18, "寒露", 10, 8), (19, "霜降", 10, 23),
        (20, "立冬", 11, 7), (21, "小雪", 11, 22), (22, "大雪", 12, 7), (23, "冬至", 12, 22)
    ]

    for term in expected {
        guard let date = SolarTerm.termDate(year: 2026, index: term.index) else {
            Issue.record("\(term.name) 未计算出日期")
            continue
        }
        #expect(
            dayKey(date) == String(format: "2026-%02d-%02d", term.month, term.day),
            "\(term.name) 实际为 \(dayKey(date))（\(date)）"
        )
        #expect(SolarTerm.name(for: makeDate(2026, term.month, term.day)) == term.name)
    }
}

@Test func solarTermNameIsNilOnOrdinaryDay() {
    #expect(SolarTerm.termDate(year: 2026, index: 24) == nil)
    #expect(SolarTerm.name(for: makeDate(2026, 11, 24)) == nil)
    #expect(SolarTerm.name(for: makeDate(2026, 11, 22)) == "小雪")
}

@Test func lunarDateText() {
    let newYear = makeDate(2026, 2, 17)
    #expect(LunarCalendar.fullText(for: newYear) == "正月初一")
    #expect(LunarCalendar.dayLabel(for: newYear) == "正月")

    let ordinary = makeDate(2026, 11, 24)
    #expect(LunarCalendar.fullText(for: ordinary) == "十月十六")
    #expect(LunarCalendar.dayLabel(for: ordinary) == "十六")

    let components = LunarCalendar.components(for: ordinary)
    #expect(components.month == 10)
    #expect(components.day == 16)
    #expect(components.isLeap == false)
}

@Test func leapMonthText() {
    let leapSixth = makeDate(2025, 7, 25)
    let components = LunarCalendar.components(for: leapSixth)
    #expect(components.isLeap)
    #expect(components.month == 6)
    #expect(components.day == 1)
    #expect(LunarCalendar.fullText(for: leapSixth).hasPrefix("闰六月"))
    #expect(LunarCalendar.dayLabel(for: leapSixth) == "闰六月")

    // 冬月（十一月）初一的格子短标签应为「冬月」。
    #expect(LunarCalendar.dayLabel(for: makeDate(2026, 12, 9)) == "冬月")
}
