import Foundation

/// 格子副标题的语义类别。配色不在此处定义，由视图层（DayCell）映射。
enum DaySubtitleKind: Equatable, Sendable {
    /// 24 节气（最高优先级）。
    case solarTerm
    /// 常见节日名（含法定节假日名）。
    case festival
    /// 农历日名，如「初八」。
    case lunarDay
    /// 农历月名，如「正月」，沿用既有的粉色强调。
    case lunarMonth
}

struct DaySubtitle: Equatable, Sendable {
    let text: String
    let kind: DaySubtitleKind
}

/// 副标题内容解析：优先级为 节气 > 节日名 > 农历。
enum DaySubtitleResolver {
    /// 三者皆缺席时返回空文本 + `.lunarDay`（不崩溃、不返回 nil）。
    static func resolve(solarTerm: String?, festivalName: String?, lunarLabel: String) -> DaySubtitle {
        if let term = normalized(solarTerm) {
            return DaySubtitle(text: term, kind: .solarTerm)
        }
        if let festival = normalized(festivalName) {
            return DaySubtitle(text: festival, kind: .festival)
        }
        return DaySubtitle(text: lunarLabel, kind: lunarKind(lunarLabel))
    }

    /// nil 与空串等价归一为「缺席」；不做 trimming，避免掩盖上游格式化问题。
    private static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// 沿用 `LunarCalendar.dayLabel` 的既有约定：月名以「月」结尾。
    private static func lunarKind(_ label: String) -> DaySubtitleKind {
        label.hasSuffix("月") ? .lunarMonth : .lunarDay
    }
}

/// 节日名筛选：法定节假日名仅在正日子展示（其余放假区间回落静态节），开关关闭时两类都不显示。
///
/// 抽成纯函数以便单测——这条口径正是「国庆区间顶掉真实节日」的防线。
enum FestivalNameSelector {
    /// - Parameters:
    ///   - storedHolidayName: `HolidayStore.name(for:)` 提供的法定假期名（可能是整个区间共用的名字）。
    ///   - catalogName: `FestivalCatalog.name(for:)` 命中的本地静态节。
    static func pick(
        storedHolidayName: String?,
        date: Date,
        catalogName: String?,
        showFestivals: Bool
    ) -> String? {
        guard showFestivals else { return nil }
        if let stored = storedHolidayName, LegalHoliday.isMainDay(name: stored, date: date) {
            return stored
        }
        return catalogName
    }
}
