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

// 覆盖「法定名仅在正日子 + 静态节回落 + 开关切断」的组合口径。

@Test func legalNameOutsideMainDayFallsBackToCatalog() {
    // 2026-02-16 快照名为「春节」，但当天是除夕。
    let picked = FestivalNameSelector.pick(
        storedHolidayName: "春节",
        date: makeDate(2026, 2, 16),
        catalogName: "除夕",
        showFestivals: true
    )
    #expect(picked == "除夕")
}

@Test func legalNameOnMainDayWins() {
    let picked = FestivalNameSelector.pick(
        storedHolidayName: "春节",
        date: makeDate(2026, 2, 17),
        catalogName: nil,
        showFestivals: true
    )
    #expect(picked == "春节")
}

@Test func legalRangeDayWithoutCatalogReturnsNil() {
    // 2026-10-02 仍是国庆假期，但非正日子，也没有静态节 → 交给农历。
    let picked = FestivalNameSelector.pick(
        storedHolidayName: "国庆节",
        date: makeDate(2026, 10, 2),
        catalogName: nil,
        showFestivals: true
    )
    #expect(picked == nil)
}

@Test func toggleOffCutsBothSources() {
    let picked = FestivalNameSelector.pick(
        storedHolidayName: "国庆节",
        date: makeDate(2026, 10, 1),
        catalogName: "情人节",
        showFestivals: false
    )
    #expect(picked == nil)
}

@Test func endToEndHolidayRangeDayResolvesToLunar() {
    let festivalName = FestivalNameSelector.pick(
        storedHolidayName: "国庆节",
        date: makeDate(2026, 10, 2),
        catalogName: FestivalCatalog.name(for: makeDate(2026, 10, 2)),
        showFestivals: true
    )
    let subtitle = DaySubtitleResolver.resolve(
        solarTerm: nil,
        festivalName: festivalName,
        lunarLabel: LunarCalendar.dayLabel(for: makeDate(2026, 10, 2))
    )
    #expect(subtitle.text == "廿二")
    #expect(subtitle.kind == .lunarDay)
}
