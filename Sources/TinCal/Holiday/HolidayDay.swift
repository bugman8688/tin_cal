import Foundation

/// 单日节假日记录。`date` 为 `yyyy-MM-dd`（Asia/Shanghai 口径）。
struct HolidayDay: Codable, Equatable {
    let date: String   // yyyy-MM-dd
    let name: String   // 中文节日名
    let isOffDay: Bool // true=放假，false=补班
}

// MARK: - 解析

extension HolidayDay {
    enum ParseError: LocalizedError {
        case emptyData
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .emptyData: "节假日数据为空"
            case .unsupportedFormat: "无法识别的节假日数据格式"
            }
        }
    }

    /// 自动识别两种来源格式并解析。
    /// - 格式 A：`{"year":2026,"days":[...]}`
    /// - 格式 B：`{"holidays":{...},"workdays":{...},"inLieuDays":{...}}`
    static func parse(data: Data) throws -> [HolidayDay] {
        guard !data.isEmpty else { throw ParseError.emptyData }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let topLevel = json as? [String: Any] else {
            throw ParseError.unsupportedFormat
        }

        if topLevel["days"] != nil {
            return try parseYearFile(data: data)
        }
        if topLevel["holidays"] != nil || topLevel["workdays"] != nil {
            return try parseFullFile(data: data)
        }
        throw ParseError.unsupportedFormat
    }

    // MARK: 格式 A：GitHub raw / jsDelivr 按年文件

    private struct YearFile: Decodable {
        let days: [YearDay]
    }

    private struct YearDay: Decodable {
        let name: String
        let date: String
        let isOffDay: Bool
    }

    private static func parseYearFile(data: Data) throws -> [HolidayDay] {
        let file = try JSONDecoder().decode(YearFile.self, from: data)
        let days = file.days.map { HolidayDay(date: $0.date, name: $0.name, isOffDay: $0.isOffDay) }
        return days.sorted { $0.date < $1.date }
    }

    // MARK: 格式 B：npmmirror chinese-days 全量

    private struct FullFile: Decodable {
        let holidays: [String: String]?
        let workdays: [String: String]?
        let inLieuDays: [String: String]?
    }

    private static func parseFullFile(data: Data) throws -> [HolidayDay] {
        let file = try JSONDecoder().decode(FullFile.self, from: data)
        var result: [String: HolidayDay] = [:]

        // holidays → 法定节假日放假。
        for (date, raw) in file.holidays ?? [:] {
            result[date] = HolidayDay(date: date, name: chineseName(from: raw), isOffDay: true)
        }
        // inLieuDays → 调休放假，同属放假，一并标记。
        for (date, raw) in file.inLieuDays ?? [:] {
            result[date] = HolidayDay(date: date, name: chineseName(from: raw), isOffDay: true)
        }
        // workdays → 补班。
        for (date, raw) in file.workdays ?? [:] {
            result[date] = HolidayDay(date: date, name: chineseName(from: raw), isOffDay: false)
        }

        return result.values.sorted { $0.date < $1.date }
    }

    /// `"National Day,国庆节,3"` → 取第 2 段中文名；取不到时退回第 1 段英文名。
    static func chineseName(from raw: String) -> String {
        let parts = raw
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count > 1, !parts[1].isEmpty {
            return parts[1]
        }
        return parts.first(where: { !$0.isEmpty }) ?? raw
    }
}
