import Foundation

/// 二十四节气：按太阳视黄经实时计算，不使用固定日期表。
enum SolarTerm {
    /// 按太阳黄经顺序排列（小寒 285° … 冬至 270°）。
    static let names = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ]

    private static let angles: [Double] = [
        285, 300, 315, 330, 345, 0,
        15, 30, 45, 60, 75, 90,
        105, 120, 135, 150, 165, 180,
        195, 210, 225, 240, 255, 270
    ]

    /// 太阳平均每日黄经增量（度）。
    private static let meanDailyMotion = 0.98564736

    private static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    private static var cache: [Int: [String: String]] = [:]
    private static let lock = NSLock()

    /// 当天若是节气则返回节气名。
    static func name(for date: Date) -> String? {
        let year = gregorian.component(.year, from: date)
        return termsByDay(in: year)[dayKey(for: date)]
    }

    /// index：0 = 小寒 … 23 = 冬至，返回该年的节气时刻（北京时间）。
    static func termDate(year: Int, index: Int) -> Date? {
        guard angles.indices.contains(index) else { return nil }
        return computeTermDate(year: year, index: index)
    }

    private static func termsByDay(in year: Int) -> [String: String] {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cache[year] { return cached }

        var result: [String: String] = [:]
        for index in names.indices {
            if let date = computeTermDate(year: year, index: index) {
                result[dayKey(for: date)] = names[index]
            }
        }
        cache[year] = result
        return result
    }

    private static func computeTermDate(year: Int, index: Int) -> Date? {
        guard let startOfYear = gregorian.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return nil
        }

        let target = angles[index]
        // 285°…345° 落在年初，按负偏移回推；其余从春分（约一年第 79 天）顺推。
        let offsetAngle = target <= 280 ? target : target - 360
        var julianDay = julianDay(from: startOfYear)
            + (79 + offsetAngle / meanDailyMotion - 1)

        for _ in 0..<8 {
            let difference = normalized180(solarLongitude(julianDay) - target)
            julianDay -= difference / meanDailyMotion
        }

        return date(fromJulianDay: julianDay)
    }

    /// 太阳视黄经（度），Meeus《Astronomical Algorithms》低精度公式，误差约 0.01°。
    private static func solarLongitude(_ julianDay: Double) -> Double {
        let t = (julianDay - 2_451_545.0) / 36_525.0

        let meanLongitude = 280.46646 + 36_000.76983 * t + 0.0003032 * t * t
        let meanAnomaly = degreesToRadians(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)

        let equationOfCenter =
            (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(meanAnomaly)
            + (0.019993 - 0.000101 * t) * sin(2 * meanAnomaly)
            + 0.000289 * sin(3 * meanAnomaly)

        let trueLongitude = meanLongitude + equationOfCenter
        let ascendingNode = degreesToRadians(125.04 - 1934.136 * t)

        // 光行差与章动修正，得到视黄经。
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(ascendingNode)
        return normalize360(apparentLongitude)
    }

    private static func julianDay(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private static func date(fromJulianDay julianDay: Double) -> Date {
        Date(timeIntervalSince1970: (julianDay - 2_440_587.5) * 86_400)
    }

    private static func dayKey(for date: Date) -> String {
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func normalize360(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static func normalized180(_ degrees: Double) -> Double {
        let value = normalize360(degrees)
        return value > 180 ? value - 360 : value
    }
}
