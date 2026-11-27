import Foundation
import Testing
@testable import TinCal

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

private let gregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = shanghai
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

// 法定节假日名字仅在「正日子」展示，其余放假区间交给静态节或农历。

@Test func springFestivalMainDayIsFirstLunarDay() {
    #expect(LegalHoliday.isMainDay(name: "春节", date: makeDate(2026, 2, 17)))
    #expect(!LegalHoliday.isMainDay(name: "春节", date: makeDate(2026, 2, 16)), "除夕不是春节正日子")
    #expect(!LegalHoliday.isMainDay(name: "春节", date: makeDate(2026, 2, 14)), "假期首日也不是正日子")
    #expect(LegalHoliday.isMainDay(name: "春节", date: makeDate(2027, 2, 6)))
}

@Test func nationalDayMainDayIsOctoberFirst() {
    #expect(LegalHoliday.isMainDay(name: "国庆节", date: makeDate(2026, 10, 1)))
    #expect(!LegalHoliday.isMainDay(name: "国庆节", date: makeDate(2026, 10, 2)))
    #expect(!LegalHoliday.isMainDay(name: "国庆节", date: makeDate(2026, 9, 30)))
}

@Test func newYearAndLabourDayMainDays() {
    #expect(LegalHoliday.isMainDay(name: "元旦", date: makeDate(2026, 1, 1)))
    #expect(!LegalHoliday.isMainDay(name: "元旦", date: makeDate(2026, 1, 2)))
    #expect(LegalHoliday.isMainDay(name: "劳动节", date: makeDate(2026, 5, 1)))
    #expect(!LegalHoliday.isMainDay(name: "劳动节", date: makeDate(2026, 5, 2)))
}

@Test func dragonBoatAndMidAutumnFollowLunarDays() {
    // 2026 端午五月初五 = 06-19；中秋八月十五 = 09-25。
    #expect(LegalHoliday.isMainDay(name: "端午", date: makeDate(2026, 6, 19)))
    #expect(!LegalHoliday.isMainDay(name: "端午", date: makeDate(2026, 6, 20)))
    #expect(LegalHoliday.isMainDay(name: "中秋", date: makeDate(2026, 9, 25)))
    #expect(!LegalHoliday.isMainDay(name: "中秋", date: makeDate(2026, 9, 26)))
}

@Test func qingmingFollowsSolarTerm() {
    // 清明的正日子就是节气当天（2026-04-05）。
    #expect(LegalHoliday.isMainDay(name: "清明", date: makeDate(2026, 4, 5)))
    #expect(!LegalHoliday.isMainDay(name: "清明", date: makeDate(2026, 4, 4)))
    #expect(!LegalHoliday.isMainDay(name: "清明", date: makeDate(2026, 4, 6)))
}

@Test func oneOffMemorialDayIsAlwaysShown() {
    let name = "中国人民抗日战争暨世界反法西斯战争胜利70周年纪念日"
    #expect(LegalHoliday.isMainDay(name: name, date: makeDate(2015, 9, 3)))
}

@Test func unknownNameFallsBackToShowing() {
    // 未收录的节名保守展示，避免新增法定节日后静默消失。
    #expect(LegalHoliday.isMainDay(name: "未来新增节", date: makeDate(2030, 1, 1)))
}
