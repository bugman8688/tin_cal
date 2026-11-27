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

/// 公历固定节日（9 条），统一用 2025 年做表驱动断言。
private let solarFestivals: [(month: Int, day: Int, name: String)] = [
    (2, 14, "情人节"),
    (3, 8, "妇女节"),
    (3, 12, "植树节"),
    (5, 4, "青年节"),
    (6, 1, "儿童节"),
    (7, 1, "建党节"),
    (8, 1, "建军节"),
    (9, 10, "教师节"),
    (12, 25, "圣诞节"),
]

// MARK: - 目录元数据

@Test func catalogMetadata() {
    #expect(FestivalCatalog.all.count == 16, "静态表应含 6 农历 + 9 公历固定 + 1 序数")
    #expect(Set(FestivalCatalog.all.map(\.id)).count == FestivalCatalog.all.count, "id 必须唯一")
    #expect(FestivalCatalog.all.allSatisfy { !$0.name.isEmpty }, "name 不可为空")
}

// MARK: - 公历固定节

@Test func fixedSolarFestivals() {
    for item in solarFestivals {
        #expect(
            FestivalCatalog.name(for: makeDate(2025, item.month, item.day)) == item.name,
            "\(item.month)/\(item.day) 应为 \(item.name)"
        )
    }
}

@Test func fixedSolarFestivalsAreYearIndependent() {
    #expect(FestivalCatalog.name(for: makeDate(2027, 2, 14)) == "情人节")
    #expect(FestivalCatalog.name(for: makeDate(2029, 12, 25)) == "圣诞节")
}

// MARK: - 农历节

@Test func lanternFestival() {
    #expect(FestivalCatalog.name(for: makeDate(2025, 2, 12)) == "元宵")
    #expect(FestivalCatalog.name(for: makeDate(2024, 2, 24)) == "元宵")
    #expect(FestivalCatalog.name(for: makeDate(2025, 2, 13)) == nil, "正月十六不应命中")
}

@Test func qixi() {
    #expect(FestivalCatalog.name(for: makeDate(2025, 8, 29)) == "七夕")
}

@Test func zhongyuanAndChongyang() {
    #expect(FestivalCatalog.name(for: makeDate(2025, 9, 6)) == "中元")
    #expect(FestivalCatalog.name(for: makeDate(2025, 10, 29)) == "重阳")
}

@Test func labaCrossesGregorianYear() {
    // 农历甲辰年腊月初八落在公历 2025 年 1 月，用于覆盖农历年跨公历年的场景。
    #expect(FestivalCatalog.name(for: makeDate(2025, 1, 7)) == "腊八")
}

// MARK: - 除夕（大小月）

@Test func newYearsEveInBigTwelfthMonth() {
    #expect(FestivalCatalog.name(for: makeDate(2024, 2, 9)) == "除夕", "2024 腊月三十")
    #expect(FestivalCatalog.name(for: makeDate(2024, 2, 10)) == nil, "次日已是正月初一")
}

@Test func newYearsEveInSmallTwelfthMonth() {
    #expect(FestivalCatalog.name(for: makeDate(2025, 1, 28)) == "除夕", "2025 腊月廿九")
    #expect(FestivalCatalog.name(for: makeDate(2025, 1, 29)) == nil)
}

@Test func newYearsEve2026Verified() {
    // 已用系统 .chinese 日历核验：2026-02-16 为腊月廿九，次日 02-17 正月初一。
    #expect(FestivalCatalog.name(for: makeDate(2026, 2, 16)) == "除夕")
}

// MARK: - 闰月守卫

@Test func leapMonthDoesNotTriggerLunarFestival() {
    // 2006 年闰七月：只有正七月初七算七夕，闰七月初七不算。
    #expect(FestivalCatalog.name(for: makeDate(2006, 7, 31)) == "七夕")
    #expect(FestivalCatalog.name(for: makeDate(2006, 8, 30)) == nil, "闰七月初七不应命中")
}

// MARK: - 月日序数节

@Test func mothersDayIsSecondSundayOfMay() {
    #expect(FestivalCatalog.name(for: makeDate(2025, 5, 11)) == "母亲节")
    #expect(FestivalCatalog.name(for: makeDate(2025, 5, 18)) == nil, "第 3 个周日不算")
    #expect(FestivalCatalog.name(for: makeDate(2024, 5, 5)) == nil, "第 1 个周日不算")
}

// MARK: - 顺序契约与设计边界

@Test func lunarFestivalWinsOverSolarOnConflictDay() {
    // 2014-02-14 既是正月十五又是情人节，数组顺序（农历在前）决定显示「元宵」。
    #expect(FestivalCatalog.name(for: makeDate(2014, 2, 14)) == "元宵")
}

@Test func chineseNewYearItselfIsNotListed() {
    // 设计边界：本表不含春节/国庆等法定节假日（它们的正日子由 LegalHoliday 判定）。
    #expect(FestivalCatalog.name(for: makeDate(2025, 1, 29)) == nil)
    #expect(FestivalCatalog.name(for: makeDate(2024, 2, 10)) == nil)
}

@Test func ordinaryDayHasNoFestival() {
    #expect(FestivalCatalog.name(for: makeDate(2025, 3, 15)) == nil)
}
