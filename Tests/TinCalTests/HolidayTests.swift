import Foundation
import Testing
@testable import TinCal

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

private let gregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = shanghai
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
    gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// 由测试文件路径推导项目根目录，避免硬编码绝对路径。
private var projectRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // TinCalTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // 项目根
}

private let snapshotURL = projectRoot.appendingPathComponent("Resources/holiday_snapshot.json")

// MARK: - 格式 A（GitHub raw / jsDelivr 按年文件）

private let yearFormatJSON = """
{
  "year": 2026,
  "days": [
    {"name": "元旦", "date": "2026-01-01", "isOffDay": true},
    {"name": "春节", "date": "2026-02-17", "isOffDay": true},
    {"name": "春节", "date": "2026-02-28", "isOffDay": false}
  ]
}
"""

@Test func parseYearFormat() throws {
    let days = try HolidayDay.parse(data: Data(yearFormatJSON.utf8))

    #expect(days.count == 3)
    #expect(days.first == HolidayDay(date: "2026-01-01", name: "元旦", isOffDay: true))
    #expect(days.last == HolidayDay(date: "2026-02-28", name: "春节", isOffDay: false))
    #expect(days.contains { $0.date == "2026-02-17" && $0.isOffDay })
}

// MARK: - 格式 B（npmmirror chinese-days 全量）

private let fullFormatJSON = """
{
  "holidays": {
    "2026-10-01": "National Day,国庆节,3",
    "2026-10-02": "National Day,国庆节,3"
  },
  "workdays": {
    "2026-09-27": "National Day,国庆节,3"
  },
  "inLieuDays": {
    "2026-10-11": "National Day,国庆节,3"
  }
}
"""

@Test func parseFullFormat() throws {
    let days = try HolidayDay.parse(data: Data(fullFormatJSON.utf8))
    let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })

    #expect(days.count == 4, "holidays / inLieuDays 都算放假，workdays 算补班")
    #expect(byDate["2026-10-01"] == HolidayDay(date: "2026-10-01", name: "国庆节", isOffDay: true))
    #expect(byDate["2026-10-02"]?.isOffDay == true)
    #expect(byDate["2026-09-27"] == HolidayDay(date: "2026-09-27", name: "国庆节", isOffDay: false))
    #expect(byDate["2026-10-11"] == HolidayDay(date: "2026-10-11", name: "国庆节", isOffDay: true), "inLieuDays 属于放假")
}

@Test func parseFullFormatFallsBackToEnglishName() throws {
    let json = #"{"holidays": {"2026-01-01": "New Year's Day,,1"}}"#
    let days = try HolidayDay.parse(data: Data(json.utf8))
    #expect(days == [HolidayDay(date: "2026-01-01", name: "New Year's Day", isOffDay: true)])
}

// MARK: - 内置快照

@Test func snapshotFileParses() throws {
    let data = try Data(contentsOf: snapshotURL)
    let days = try HolidayDay.parse(data: data)

    #expect(days.count > 600, "快照应包含多年全量数据，实际 \(days.count) 条")
    let nationalDay = days.first { $0.date == "2026-10-01" }
    #expect(nationalDay?.isOffDay == true)
    #expect(nationalDay?.name == "国庆节")
}

// MARK: - 时区与年份过滤

@Test func dateKeyUsesShanghaiTimeZone() {
    // UTC 下是 2025-12-31 16:30，按 Asia/Shanghai 必须是 2026-01-01。
    let date = makeDate(2026, 1, 1, hour: 0, minute: 30)
    #expect(HolidayStore.key(for: date) == "2026-01-01")
}

@Test @MainActor func unofficialYearHasNoMarker() {
    let store = HolidayStore(snapshotURL: snapshotURL)

    // 快照里虽然有 2027 数据，但 2027 未官方发布，不应返回角标依据。
    #expect(store.isOffDay(for: makeDate(2027, 1, 1)) == nil)
    #expect(store.day(for: makeDate(2027, 1, 1)) == nil)

    // 已发布年份可正常命中。
    #expect(store.isOffDay(for: makeDate(2026, 10, 1)) == true)
}
