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

@Test func november2026StartsWithSunday() {
    // 2026-11-01 是周日，11 月共 30 天，补位后为 5 行 35 格。
    let days = MonthGrid.days(for: makeDate(2026, 11, 15))
    let inMonthCount = days.filter { $0.isInMonth }.count
    let allIDsWellFormed = days.allSatisfy { $0.id.count == 10 }

    #expect(days.count == 35)
    #expect(days.count % 7 == 0)
    #expect(days.first?.id == "2026-11-01")
    #expect(days.first?.dayNumber == 1)
    #expect(inMonthCount == 30)
    #expect(days.last?.id.hasPrefix("2026-12") == true)
    #expect(allIDsWellFormed)
}

@Test func february2026IsExactlyFourWeeks() {
    // 2026-02-01 是周日，28 天 → 恰好 4 行 28 格。
    let days = MonthGrid.days(for: makeDate(2026, 2, 10))
    let allInMonth = days.allSatisfy { $0.isInMonth }

    #expect(days.count == 28)
    #expect(days.first?.id == "2026-02-01")
    #expect(days.last?.id == "2026-02-28")
    #expect(allInMonth)
    #expect(days.first?.isToday == false)
}

@Test func decemberGridSpansNextYear() {
    let days = MonthGrid.days(for: makeDate(2026, 12, 1))
    let inMonthCount = days.filter { $0.isInMonth }.count

    #expect(days.count % 7 == 0)
    #expect(inMonthCount == 31)
    #expect(days.last?.id.hasPrefix("2027-01") == true)
}

@Test func addingMonthsAnchorsToFirstDay() {
    let nextMonth = MonthGrid.addingMonths(1, to: makeDate(2026, 12, 15))
    let previousMonth = MonthGrid.addingMonths(-1, to: makeDate(2026, 1, 15))
    let sameMonth = MonthGrid.addingMonths(0, to: makeDate(2026, 11, 24))

    #expect(dayKey(nextMonth) == "2027-01-01")
    #expect(dayKey(previousMonth) == "2025-12-01")
    #expect(dayKey(sameMonth) == "2026-11-01")
}

@Test func monthTitleIsChinese() {
    #expect(MonthGrid.monthTitle(for: makeDate(2026, 11, 24)) == "2026 / 11")
    #expect(MonthGrid.monthTitle(for: makeDate(2027, 1, 1)) == "2027 / 1")
}

@Test func todayFlagMarksMatchingDay() {
    let today = makeDate(2026, 11, 24)
    let days = MonthGrid.days(for: today, today: today)
    let marked = days.filter { $0.isToday }

    #expect(marked.count == 1)
    #expect(marked.first?.id == "2026-11-24")
}
