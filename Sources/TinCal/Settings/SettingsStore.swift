import Combine
import Foundation

final class SettingsStore: ObservableObject {
    private enum Key {
        static let use24Hour = "settings.use24Hour"
        static let showWeekday = "settings.showWeekday"
        static let showSeconds = "settings.showSeconds"
        static let primarySourceID = "settings.primarySourceID"
        static let showFestivals = "settings.showFestivals"
    }

    private let userDefaults: UserDefaults

    @Published var use24Hour: Bool {
        didSet { userDefaults.set(use24Hour, forKey: Key.use24Hour) }
    }

    @Published var showWeekday: Bool {
        didSet { userDefaults.set(showWeekday, forKey: Key.showWeekday) }
    }

    @Published var showSeconds: Bool {
        didSet { userDefaults.set(showSeconds, forKey: Key.showSeconds) }
    }

    @Published var primarySourceID: String {
        didSet { userDefaults.set(primarySourceID, forKey: Key.primarySourceID) }
    }

    /// 是否在月历副标题显示节日名（含法定节假日名），默认开启。
    @Published var showFestivals: Bool {
        didSet { userDefaults.set(showFestivals, forKey: Key.showFestivals) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // 初始化时的赋值不会触发 didSet，因此这里显式读取持久化值。
        self.use24Hour = userDefaults.object(forKey: Key.use24Hour) as? Bool ?? true
        self.showWeekday = userDefaults.object(forKey: Key.showWeekday) as? Bool ?? true
        self.showSeconds = userDefaults.object(forKey: Key.showSeconds) as? Bool ?? false
        self.primarySourceID = userDefaults.object(forKey: Key.primarySourceID) as? String ?? "github"
        self.showFestivals = userDefaults.object(forKey: Key.showFestivals) as? Bool ?? true
    }

    // MARK: - 时间格式化

    private static let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    private static func makeFormatter(
        _ format: String,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = shanghai
        formatter.dateFormat = format
        return formatter
    }

    private lazy var dateFormatter = Self.makeFormatter("M月d日")
    private lazy var time24Formatter = Self.makeFormatter("HH:mm")
    private lazy var time24SecondsFormatter = Self.makeFormatter("HH:mm:ss")
    private lazy var time12Formatter = Self.makeFormatter("a h:mm", locale: Locale(identifier: "zh_CN"))
    private lazy var time12SecondsFormatter = Self.makeFormatter("a h:mm:ss", locale: Locale(identifier: "zh_CN"))
    private lazy var weekdayFormatter = Self.makeFormatter("EEE", locale: Locale(identifier: "zh_CN"))

    func timeText(for date: Date) -> String {
        let time: String
        if use24Hour {
            let formatter = showSeconds ? time24SecondsFormatter : time24Formatter
            time = formatter.string(from: date)
        } else {
            let formatter = showSeconds ? time12SecondsFormatter : time12Formatter
            // zh_CN 的 a 可能带空格，统一去掉，输出「下午3:41」。
            time = formatter.string(from: date).filter { !$0.isWhitespace }
        }

        var parts = [dateFormatter.string(from: date)]
        if showWeekday {
            parts.append(weekdayFormatter.string(from: date))
        }
        parts.append(time)
        return parts.joined(separator: " ")
    }
}
