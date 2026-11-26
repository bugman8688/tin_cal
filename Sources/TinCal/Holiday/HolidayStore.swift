import Combine
import Foundation

/// 节假日数据层：主源 → 备源 → 本地缓存 → 内置快照。
@MainActor
final class HolidayStore: ObservableObject {
    struct Status: Equatable {
        /// 实际数据来源，如「GitHub raw」「缓存」「内置快照」。
        var sourceLabel: String
        var updatedAt: Date?
        /// 错误 / 降级说明。
        var message: String?
        var isRefreshing: Bool
    }

    /// 已官方发布的年份；后续手动维护。未收录年份不渲染休/班角标。
    nonisolated static let officialYears: Set<Int> = [2025, 2026]

    @Published private(set) var days: [String: HolidayDay] = [:]
    @Published private(set) var status: Status

    private let session: URLSession
    private let cacheURL: URL

    nonisolated private static let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    init(snapshotURL: URL? = nil, cacheURL: URL? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: configuration)
        self.cacheURL = cacheURL ?? Self.defaultCacheURL
        self.status = Status(sourceLabel: "内置快照", updatedAt: nil, message: nil, isRefreshing: false)
        loadSnapshot(from: snapshotURL ?? Bundle.main.url(forResource: "holiday_snapshot", withExtension: "json"))
    }

    // MARK: - 查询

    /// `yyyy-MM-dd` 的日期键，按 Asia/Shanghai 时区格式化。
    nonisolated static func key(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    nonisolated static func year(for date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        return calendar.component(.year, from: date)
    }

    /// 非官方年份一律返回 nil，UI 据此不画角标。
    func day(for date: Date) -> HolidayDay? {
        guard Self.officialYears.contains(Self.year(for: date)) else { return nil }
        return days[Self.key(for: date)]
    }

    func isOffDay(for date: Date) -> Bool? {
        day(for: date)?.isOffDay
    }

    // MARK: - 刷新

    func refresh(primarySourceID: String) async {
        let primary = HolidaySource(rawValue: primarySourceID) ?? .github
        var order: [HolidaySource] = [primary]
        for source in HolidaySource.allCases where source != primary {
            order.append(source)
        }

        status.isRefreshing = true
        defer { status.isRefreshing = false }

        var failures: [String] = []
        for source in order {
            do {
                let fetched = try await fetch(source)
                guard !fetched.isEmpty else {
                    failures.append("\(source.displayName)：无数据")
                    continue
                }
                merge(fetched)
                let now = Date()
                status.sourceLabel = source.displayName
                status.updatedAt = now
                status.message = nil
                do {
                    try writeCache(sourceID: source.rawValue, updatedAt: now)
                } catch {
                    status.message = "缓存写入失败：\(error.localizedDescription)"
                }
                return
            } catch {
                failures.append("\(source.displayName)：\(Self.describe(error))")
            }
        }

        let reason = failures.joined(separator: "；")
        if let cache = readCache() {
            merge(cache.days)
            status.sourceLabel = "缓存"
            status.updatedAt = cache.updatedAt
            status.message = "全部源不可用，已使用本地缓存（\(reason)）"
        } else {
            status.sourceLabel = "内置快照"
            status.message = "全部源不可用，已保持内置快照（\(reason)）"
        }
    }

    // MARK: - 探测

    func probe(_ source: HolidaySource) async -> ProbeResult {
        let url = source.url(forYear: 2026) // 按年源探测 2026；npmmirror 本身忽略年份
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return ProbeResult(status: .failed("HTTP \(http.statusCode)"))
            }
            _ = try HolidayDay.parse(data: data)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return ProbeResult(status: .available(latencyMs: latency))
        } catch {
            return ProbeResult(status: .failed(Self.describe(error)))
        }
    }

    // MARK: - 网络

    private enum FetchError: Error {
        case http(Int)
        case parse
    }

    private static func describe(_ error: Error) -> String {
        if let fetchError = error as? FetchError {
            switch fetchError {
            case let .http(code): return "HTTP \(code)"
            case .parse: return "解析失败"
            }
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return "超时"
        }
        if let urlError = error as? URLError {
            return "网络错误(\(urlError.code.rawValue))"
        }
        return "请求失败"
    }

    private func fetch(_ source: HolidaySource) async throws -> [HolidayDay] {
        let officialPrefixes = Self.officialYears.map(String.init)

        if source.isYearly {
            var result: [HolidayDay] = []
            for year in Self.officialYears.sorted() {
                result.append(contentsOf: try await fetchFile(source, year: year))
            }
            return result
        }

        let all = try await fetchFile(source, year: Self.officialYears.min() ?? 2026)
        return all.filter { officialPrefixes.contains(String($0.date.prefix(4))) }
    }

    private func fetchFile(_ source: HolidaySource, year: Int) async throws -> [HolidayDay] {
        var request = URLRequest(url: source.url(forYear: year))
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.http(http.statusCode)
        }
        do {
            return try HolidayDay.parse(data: data)
        } catch {
            throw FetchError.parse
        }
    }

    // MARK: - 快照

    private func loadSnapshot(from url: URL?) {
        guard let url else {
            status.message = "未找到内置快照 holiday_snapshot.json"
            return
        }
        do {
            let data = try Data(contentsOf: url)
            merge(try HolidayDay.parse(data: data))
        } catch {
            status.message = "内置快照读取失败：\(error.localizedDescription)"
        }
    }

    private func merge(_ items: [HolidayDay]) {
        for item in items {
            days[item.date] = item
        }
    }

    // MARK: - 缓存

    private struct CacheFile: Codable {
        let updatedAt: Date
        let sourceID: String
        let days: [HolidayDay]
    }

    private static var defaultCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("tin_cal/holiday_cache.json")
    }

    private func writeCache(sourceID: String, updatedAt: Date) throws {
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = CacheFile(
            updatedAt: updatedAt,
            sourceID: sourceID,
            days: days.values.sorted { $0.date < $1.date }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        // 原子写：先写临时文件，再替换目标文件。
        let tempURL = cacheURL.deletingLastPathComponent()
            .appendingPathComponent("holiday_cache.\(UUID().uuidString).tmp")
        try data.write(to: tempURL)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            _ = try FileManager.default.replaceItemAt(cacheURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: cacheURL)
        }
    }

    private func readCache() -> (updatedAt: Date, days: [HolidayDay])? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(CacheFile.self, from: data) else { return nil }
        return (file.updatedAt, file.days)
    }
}
