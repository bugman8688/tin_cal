import Foundation

/// 节假日数据来源。
enum HolidaySource: String, CaseIterable, Identifiable {
    case github
    case jsdelivr
    case npmmirror

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .github: "GitHub raw"
        case .jsdelivr: "jsDelivr"
        case .npmmirror: "npmmirror"
        }
    }

    var detail: String {
        switch self {
        case .github: "按年获取 GitHub 原始文件，数据最新，国内可能较慢"
        case .jsdelivr: "按年获取 jsDelivr CDN 缓存，速度较快"
        case .npmmirror: "国内镜像，一次获取全量数据后本地过滤"
        }
    }

    /// 是否按年分文件（npmmirror 为全量，年份参数被忽略）。
    var isYearly: Bool { self != .npmmirror }

    func url(forYear year: Int) -> URL {
        switch self {
        case .github:
            URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!
        case .jsdelivr:
            URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!
        case .npmmirror:
            URL(string: "https://registry.npmmirror.com/chinese-days/2.0.0/files/dist/chinese-days.json")!
        }
    }
}

/// 源连通性探测状态。
enum ProbeStatus: Equatable {
    case idle
    case testing
    case available(latencyMs: Int)
    case failed(String)
}

struct ProbeResult {
    let status: ProbeStatus
}
