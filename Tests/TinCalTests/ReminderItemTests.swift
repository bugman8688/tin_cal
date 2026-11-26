import Foundation
import Testing
@testable import TinCal

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

private let gregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = shanghai
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
    gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// 构造 UTC 时刻，用于验证跨时区归属边界。
private func makeUTCDate(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func makeItem(
    _ id: String,
    title: String = "待办",
    day: (Int, Int, Int),
    hour: Int = 9,
    isCompleted: Bool = false
) -> ReminderItem {
    guard let item = ReminderItem.makeSnapshot(
        id: id,
        title: title,
        dueDay: makeDate(day.0, day.1, day.2, hour: hour),
        dueMinutes: hour * 60,
        isCompleted: isCompleted
    ) else {
        fatalError("fixture invalid: \(id)")
    }
    return item
}

/// 构造无具体时刻（全天）的提醒。
private func makeAllDayItem(_ id: String, day: (Int, Int, Int)) -> ReminderItem {
    guard let item = ReminderItem.makeSnapshot(
        id: id,
        title: "全天",
        dueDay: makeDate(day.0, day.1, day.2),
        dueMinutes: nil,
        isCompleted: false
    ) else {
        fatalError("fixture invalid: \(id)")
    }
    return item
}

@Test func makeSnapshotReturnsNilWithoutDueDay() {
    let item = ReminderItem.makeSnapshot(
        id: "no-due",
        title: "无截止日",
        dueDay: nil,
        notes: nil,
        listName: nil,
        isCompleted: false
    )

    #expect(item == nil)
}

@Test func makeSnapshotPreservesCompletedFlag() {
    // makeSnapshot 不做完成态筛选，「仅未完成」由 filterActive 负责。
    let item = makeItem("done", day: (2026, 11, 24), isCompleted: true)

    #expect(item.isCompleted)
}

@Test func makeSnapshotNormalizesToStartOfDay() {
    let item = makeItem("normalize", day: (2026, 11, 24), hour: 15)
    let expected = gregorian.startOfDay(for: makeDate(2026, 11, 24, hour: 15))

    #expect(item.dueDay == expected)
}

@Test func filterActiveDropsCompleted() {
    let active = makeItem("a", day: (2026, 11, 24))
    let done = makeItem("b", day: (2026, 11, 24), isCompleted: true)
    let another = makeItem("c", day: (2026, 11, 25))

    let result = ReminderItem.filterActive([active, done, another])

    #expect(result.map(\.id) == ["a", "c"])
}

@Test func filterActiveOnEmptyInput() {
    #expect(ReminderItem.filterActive([]).isEmpty)
}

@Test func groupByDayKeyAssignsItemsToTheirDay() {
    let first = makeItem("a", day: (2026, 11, 24))
    let second = makeItem("b", day: (2026, 11, 25))
    let third = makeItem("c", day: (2027, 1, 1))

    let grouped = ReminderItem.groupByDayKey([first, second, third])

    #expect(grouped.keys.sorted() == ["2026-11-24", "2026-11-25", "2027-01-01"])
    #expect(grouped["2026-11-24"]?.map(\.id) == ["a"])
    #expect(grouped["2026-11-25"]?.map(\.id) == ["b"])
    #expect(grouped["2027-01-01"]?.map(\.id) == ["c"])
}

@Test func groupByDayKeyTreatsDifferentHoursOfSameDayAsOneKey() {
    let morning = makeItem("morning", day: (2026, 11, 24), hour: 8)
    let evening = makeItem("evening", day: (2026, 11, 24), hour: 22)

    let grouped = ReminderItem.groupByDayKey([morning, evening])

    #expect(grouped.count == 1)
    #expect(grouped["2026-11-24"]?.count == 2)
}

@Test func groupByDayKeyOnEmptyInput() {
    #expect(ReminderItem.groupByDayKey([]).isEmpty)
}

@Test func dayKeyMatchesMonthGridKey() {
    // 用月历网格自身的 id（即 MonthGrid.key(for:) 的输出）锁住两个模块的日期键口径一致。
    let anchor = makeDate(2026, 11, 15)
    let days = MonthGrid.days(for: anchor, today: anchor)

    #expect(!days.isEmpty)
    for day in days {
        #expect(ReminderItem.dayKey(for: day.date) == day.id)
    }
}

@Test func dayKeyHandlesUtcMomentMappedToShanghaiNextDay() {
    // UTC 2026-11-24 16:30 = 上海 2026-11-25 00:30，应归属到次日。
    let utcMoment = makeUTCDate(2026, 11, 24, hour: 16, minute: 30)

    #expect(ReminderItem.dayKey(for: utcMoment) == "2026-11-25")
}

@Test func dayKeyKeepsSameDayAtMidnightEdges() {
    #expect(ReminderItem.dayKey(for: makeDate(2026, 11, 24, hour: 0, minute: 0)) == "2026-11-24")
    #expect(ReminderItem.dayKey(for: makeDate(2026, 11, 24, hour: 23, minute: 59)) == "2026-11-24")
}

@Test func dayKeyDoesNotCrossYearAtNewYearsEve() {
    #expect(ReminderItem.dayKey(for: makeDate(2026, 12, 31, hour: 23, minute: 59)) == "2026-12-31")
}

@Test func makeSnapshotTruncatesToShanghaiStartOfDayAcrossUtcBoundary() {
    // UTC 2026-11-24 16:30 = 上海 2026-11-25 00:30；快照应归一到 2026-11-25 00:00。
    let item = ReminderItem.makeSnapshot(
        id: "utc",
        title: "跨时区",
        dueDay: makeUTCDate(2026, 11, 24, hour: 16, minute: 30),
        isCompleted: false
    )!
    let expected = gregorian.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 0, minute: 0))!

    #expect(item.dueDay == expected)
}

@Test func makeSnapshotAndFilterActiveEndToEnd() {
    // 组合链路：makeSnapshot 保留完成标记，filterActive 负责剔除。
    let result = ReminderItem.filterActive([
        makeItem("a", day: (2026, 11, 24)),
        makeItem("b", day: (2026, 11, 24), isCompleted: true),
    ])

    #expect(result.map(\.id) == ["a"])
}

@Test func makeSnapshotNormalizesEmptyTextToNil() {
    let item = ReminderItem.makeSnapshot(
        id: "empty",
        title: "空文本",
        dueDay: makeDate(2026, 11, 24),
        notes: "",
        listName: "",
        isCompleted: false
    )!

    #expect(item.notes == nil)
    #expect(item.listName == nil)
}

// MARK: - 同日排序

@Test func sortedByDueTimeOrdersByMinutesThenTitle() {
    let late = makeItem("late", title: "晚", day: (2026, 11, 24), hour: 18)
    let early = makeItem("early", title: "早", day: (2026, 11, 24), hour: 9)
    // 同刻用标题码点序（不引入本地化比较），再用 id 兜底。
    let tieA = makeItem("tie-a", title: "A班", day: (2026, 11, 24), hour: 9)
    let tieB = makeItem("tie-b", title: "B班", day: (2026, 11, 24), hour: 9)

    let result = ReminderItem.sortedByDueTime([late, tieB, early, tieA])

    // 注意依赖码点序（非本地化字序）：A班 < B班 < 早；同刻兜底不是拼音序。
    #expect(result.map(\.id) == ["tie-a", "tie-b", "early", "late"])
}

@Test func sortedByDueTimeTieOnSameTitleFallsBackToId() {
    let b = makeItem("b-id", title: "同名", day: (2026, 11, 24), hour: 9)
    let a = makeItem("a-id", title: "同名", day: (2026, 11, 24), hour: 9)

    let result = ReminderItem.sortedByDueTime([b, a])

    #expect(result.map(\.id) == ["a-id", "b-id"])
}

@Test func sortedByDueTimePutsAllDayFirst() {
    let allDay = makeAllDayItem("all-day", day: (2026, 11, 24))
    let timed = makeItem("timed", day: (2026, 11, 24), hour: 8)

    let result = ReminderItem.sortedByDueTime([timed, allDay])

    #expect(result.map(\.id) == ["all-day", "timed"])
}

@Test func sortedByDueTimeDoesNotChangeGroupingOrCompletion() {
    // 排序纯函数：不改 dueDay 归属，也不改变完成态（筛选仍由 filterActive 负责）。
    let morning = makeItem("morning", day: (2026, 11, 24), hour: 8)
    let evening = makeItem("evening", day: (2026, 11, 25), hour: 22, isCompleted: true)

    let result = ReminderItem.sortedByDueTime([evening, morning])

    #expect(result.map(\.id) == ["morning", "evening"])
    #expect(result.map(\.dueDay) == [morning.dueDay, evening.dueDay])
    #expect(result.map(\.isCompleted) == [false, true])
}

@Test func groupByDayKeyAssignsUtcBoundaryItemToNextDay() {
    // UTC 2026-11-24 16:30 = 上海 2026-11-25 00:30，应归属到 11-25。
    let item = ReminderItem.makeSnapshot(
        id: "utc",
        title: "跨时区",
        dueDay: makeUTCDate(2026, 11, 24, hour: 16, minute: 30),
        isCompleted: false
    )!

    #expect(ReminderItem.groupByDayKey([item]).keys.sorted() == ["2026-11-25"])
}

// MARK: - 过期过滤

private let expiryNow = makeDate(2026, 11, 25, hour: 9, minute: 15)

@Test func isExpiredDropsPastDay() {
    let yesterday = makeItem("yesterday", day: (2026, 11, 24), hour: 9)

    #expect(ReminderItem.isExpired(yesterday, now: expiryNow))
}

@Test func isExpiredKeepsFutureDay() {
    let tomorrow = makeItem("tomorrow", day: (2026, 11, 26), hour: 9)

    #expect(!ReminderItem.isExpired(tomorrow, now: expiryNow))
}

@Test func isExpiredDropsTodayPastDueMinutes() {
    // 今天 09:00 的提醒，现在 09:15 → 已过时刻，剔除。
    let item = makeItem("today-past", day: (2026, 11, 25), hour: 9)

    #expect(ReminderItem.isExpired(item, now: expiryNow))
}

@Test func isExpiredKeepsTodayBeforeDueMinutes() {
    // 今天 10:00 的提醒，现在 09:15 → 未到时刻，保留。
    let item = makeItem("today-future", day: (2026, 11, 25), hour: 10)

    #expect(!ReminderItem.isExpired(item, now: expiryNow))
}

@Test func isExpiredKeepsTodayAtExactDueMinute() {
    // 边界：当前分钟恰等于提醒时刻 → 保留（提醒当分钟仍显示，下一分钟起隐藏）。
    let item = makeItem("today-exact", day: (2026, 11, 25), hour: 9)
    let now = makeDate(2026, 11, 25, hour: 9, minute: 0)

    #expect(!ReminderItem.isExpired(item, now: now))
}

@Test func isExpiredKeepsTodayAllDay() {
    // 今天到期但无具体时刻（全天）→ 当天保留。
    let item = makeAllDayItem("today-allday", day: (2026, 11, 25))

    #expect(!ReminderItem.isExpired(item, now: expiryNow))
}

@Test func filterUnexpiredRemovesOnlyExpired() {
    let yesterday = makeItem("yesterday", day: (2026, 11, 24), hour: 9)
    let today = makeItem("today", day: (2026, 11, 25), hour: 10)
    let future = makeItem("future", day: (2026, 12, 1), hour: 9)

    let result = ReminderItem.filterUnexpired([yesterday, today, future], now: expiryNow)

    #expect(result.map(\.id) == ["today", "future"])
}

@Test func filterUnexpiredCombinesWithFilterActive() {
    // 已完成 + 过期组合：filterActive 剔未完成口径，filterUnexpired 独立剔过期，两者串联无残留。
    let doneAndExpired = makeItem("done-expired", day: (2026, 11, 24), isCompleted: true)
    let activeAndExpired = makeItem("active-expired", day: (2026, 11, 24))
    let activeAndLive = makeItem("active-live", day: (2026, 11, 25), hour: 10)

    let result = ReminderItem.filterUnexpired(
        ReminderItem.filterActive([doneAndExpired, activeAndExpired, activeAndLive]),
        now: expiryNow
    )

    #expect(result.map(\.id) == ["active-live"])
}

@Test func isExpiredNormalizesNowToShanghaiDay() {
    // UTC 2026-11-24 16:30 = 上海 2026-11-25 00:30；以「今日」为 11-25 判定。
    let utcNow = makeUTCDate(2026, 11, 24, hour: 16, minute: 30)
    let yesterdayInShanghai = makeItem("sh-yesterday", day: (2026, 11, 24), hour: 9)
    let todayAllDay = makeAllDayItem("sh-today-allday", day: (2026, 11, 25))

    #expect(ReminderItem.isExpired(yesterdayInShanghai, now: utcNow))
    #expect(!ReminderItem.isExpired(todayAllDay, now: utcNow))
}
