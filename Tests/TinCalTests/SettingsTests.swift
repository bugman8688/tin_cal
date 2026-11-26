import Foundation
import Testing

@testable import TinCal

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

private func makeShanghaiDate(hour: Int, minute: Int, second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = shanghai
    return calendar.date(from: DateComponents(
        year: 2026,
        month: 11,
        day: 23,
        hour: hour,
        minute: minute,
        second: second
    ))!
}

// MARK: - 数据源

@Test func allHolidaySourcesAreExposed() {
    let cases = HolidaySource.allCases
    #expect(cases.count == 3)
    #expect(cases.contains(.github))
    #expect(cases.contains(.jsdelivr))
    #expect(cases.contains(.npmmirror))

    for source in cases {
        #expect(!source.displayName.isEmpty, "\(source.rawValue) 缺少 displayName")
        #expect(!source.detail.isEmpty, "\(source.rawValue) 缺少 detail")
    }
}

// MARK: - 设置持久化

@Test func settingsPersistAcrossInstances() {
    let suiteName = "tincal.tests.settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let first = SettingsStore(userDefaults: defaults)
    #expect(first.use24Hour == true, "默认应为 24 小时制")
    first.use24Hour = false

    let second = SettingsStore(userDefaults: defaults)
    #expect(second.use24Hour == false, "新实例应读到已持久化的值")
}

// MARK: - 时间格式

@Test func timeTextRespects24HourSetting() {
    let suiteName = "tincal.tests.time.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(userDefaults: defaults)
    settings.showWeekday = false
    settings.showSeconds = false

    settings.use24Hour = true
    #expect(settings.timeText(for: makeShanghaiDate(hour: 15, minute: 41)) == "11月23日 15:41")

    settings.use24Hour = false
    #expect(settings.timeText(for: makeShanghaiDate(hour: 15, minute: 41)) == "11月23日 下午3:41")
}
