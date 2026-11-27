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

/// 由测试文件路径推导项目根目录，复用内置快照（含 npmmirror 复合命名）。
private var snapshotURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // TinCalTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // 项目根
        .appendingPathComponent("Resources/holiday_snapshot.json")
}

// MARK: - 文案

@Test func offDayHint() {
    let hint = HolidayAdjustHint.make(name: "国庆节", isOffDay: true)
    #expect(hint.text == "(国庆节，休息)")
    #expect(hint.kind == .offDay)
}

@Test func workDayHint() {
    let hint = HolidayAdjustHint.make(name: "国庆节", isOffDay: false)
    #expect(hint.text == "(国庆节，上班)")
    #expect(hint.kind == .workDay)
}

@Test func blankNameFallsBackToActionOnly() {
    #expect(HolidayAdjustHint.make(name: nil, isOffDay: true).text == "(休息)")
    #expect(HolidayAdjustHint.make(name: "   ", isOffDay: false).text == "(上班)")
}

@Test func nameIsTrimmed() {
    #expect(HolidayAdjustHint.make(name: " 春节 ", isOffDay: true).text == "(春节，休息)")
}

// MARK: - 与 HolidayStore 集成

/// 快照里 workdays / inLieuDays 的原始名是「National Day,国庆节,3」这类复合串，
/// `HolidayStore.name(for:)` 必须给出中文节日名，否则会渲染成 `(National Day,国庆节,3，上班)`。
@Test @MainActor func workdayUsesChineseFestivalName() {
    let store = HolidayStore(snapshotURL: snapshotURL)
    let date = makeDate(2026, 10, 10)

    #expect(store.day(for: date)?.isOffDay == false)
    #expect(store.name(for: date) == "国庆节")

    let hint = HolidayAdjustHint.make(name: store.name(for: date), isOffDay: store.day(for: date)!.isOffDay)
    #expect(hint.text == "(国庆节，上班)")
    #expect(hint.kind == .workDay)
}

@Test @MainActor func inLieuDayUsesChineseFestivalName() {
    let store = HolidayStore(snapshotURL: snapshotURL)
    let date = makeDate(2026, 10, 6)

    #expect(store.day(for: date)?.isOffDay == true)
    #expect(store.name(for: date) == "国庆节")

    let hint = HolidayAdjustHint.make(name: store.name(for: date), isOffDay: store.day(for: date)!.isOffDay)
    #expect(hint.text == "(国庆节，休息)")
    #expect(hint.kind == .offDay)
}

@Test @MainActor func unofficialYearProducesNoHint() {
    let store = HolidayStore(snapshotURL: snapshotURL)
    // 快照含 2027 数据，但未官方发布，不得作为调休提示依据。
    #expect(store.day(for: makeDate(2027, 10, 1)) == nil)
}
