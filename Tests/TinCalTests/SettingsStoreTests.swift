import Foundation
import Testing

@testable import TinCal

private func makeShanghaiDate(hour: Int, minute: Int, second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    var components = DateComponents()
    components.year = 2026
    components.month = 11
    components.day = 23 // 星期一
    components.hour = hour
    components.minute = minute
    components.second = second
    return calendar.date(from: components)!
}

/// 用独立的 UserDefaults suite，避免污染真实偏好。
private func withSettings(_ body: (SettingsStore) -> Void) {
    let suiteName = "tincal.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    body(SettingsStore(userDefaults: defaults))
}

@Test func timeText24Hour() {
    withSettings { settings in
        settings.use24Hour = true
        settings.showSeconds = false
        settings.showWeekday = false
        #expect(settings.timeText(for: makeShanghaiDate(hour: 15, minute: 41)) == "11月23日 15:41")
    }
}

@Test func timeText24HourWithSeconds() {
    withSettings { settings in
        settings.use24Hour = true
        settings.showSeconds = true
        settings.showWeekday = false
        #expect(settings.timeText(for: makeShanghaiDate(hour: 15, minute: 41, second: 59)) == "11月23日 15:41:59")
    }
}

@Test func timeText12Hour() {
    withSettings { settings in
        settings.use24Hour = false
        settings.showSeconds = false
        settings.showWeekday = false
        #expect(settings.timeText(for: makeShanghaiDate(hour: 15, minute: 41)) == "11月23日 下午3:41")
    }
}

@Test func timeText12HourWithWeekday() {
    withSettings { settings in
        settings.use24Hour = false
        settings.showSeconds = false
        settings.showWeekday = true
        #expect(settings.timeText(for: makeShanghaiDate(hour: 15, minute: 41)) == "11月23日 周一 下午3:41")
    }
}

// MARK: - 节日开关

@Test func showFestivalsDefaultsToTrue() {
    withSettings { settings in
        #expect(settings.showFestivals == true, "未设置过时应默认开启")
    }
}

@Test func showFestivalsPersistsFalse() {
    // 必须写非默认值，否则「重新读取」只是又验证了一遍默认值。
    let suiteName = "tincal.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var store = SettingsStore(userDefaults: defaults)
    store.showFestivals = false

    let reloaded = SettingsStore(userDefaults: defaults)
    #expect(reloaded.showFestivals == false)
}
