import Foundation
import Testing
@testable import TinCal

// 副标题优先级（节气 > 节日名 > 农历）是产品决策，改动需同步产品口径。
// 当前数据下不存在「节气与节日同日」的真实日期，故用合成入参固定规则；
// 真实重叠表现交由真机观察。

@Test func solarTermWinsOverFestival() {
    let resolved = DaySubtitleResolver.resolve(solarTerm: "清明", festivalName: "情人节", lunarLabel: "初七")
    #expect(resolved == DaySubtitle(text: "清明", kind: .solarTerm))
}

@Test func festivalWinsOverLunarLabel() {
    let resolved = DaySubtitleResolver.resolve(solarTerm: nil, festivalName: "情人节", lunarLabel: "初七")
    #expect(resolved == DaySubtitle(text: "情人节", kind: .festival))
}

@Test func fallsBackToLunarLabelWhenNoTermOrFestival() {
    let resolved = DaySubtitleResolver.resolve(solarTerm: nil, festivalName: nil, lunarLabel: "初八")
    #expect(resolved == DaySubtitle(text: "初八", kind: .lunarDay))
}

@Test func lunarLabelKindDistinguishesMonthFromDay() {
    let cases: [(label: String, kind: DaySubtitleKind)] = [
        ("正月", .lunarMonth),
        ("六月", .lunarMonth),
        ("腊月", .lunarMonth),
        ("初一", .lunarDay),
        ("十五", .lunarDay),
        ("三十", .lunarDay),
    ]
    for item in cases {
        let resolved = DaySubtitleResolver.resolve(solarTerm: nil, festivalName: nil, lunarLabel: item.label)
        #expect(resolved == DaySubtitle(text: item.label, kind: item.kind), "\(item.label) 应为 \(item.kind)")
    }
}

@Test func blankTermAndFestivalAreTreatedAsAbsent() {
    // 空串视同缺席，回落到下一优先级。
    let fallback = DaySubtitleResolver.resolve(solarTerm: "", festivalName: "", lunarLabel: "十五")
    #expect(fallback == DaySubtitle(text: "十五", kind: .lunarDay))

    // lunarLabel 不参与归一化：前置分支命中时空串不影响结果。
    let termWins = DaySubtitleResolver.resolve(solarTerm: "清明", festivalName: nil, lunarLabel: "")
    #expect(termWins == DaySubtitle(text: "清明", kind: .solarTerm))
}

@Test func allInputsAbsentYieldsEmptyLunarDay() {
    // 不可达的降级路径：仅锁行为，防止未来重构改变语义。
    let resolved = DaySubtitleResolver.resolve(solarTerm: nil, festivalName: nil, lunarLabel: "")
    #expect(resolved == DaySubtitle(text: "", kind: .lunarDay))
}
