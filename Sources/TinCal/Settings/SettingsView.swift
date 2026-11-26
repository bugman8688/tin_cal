import SwiftUI

/// 设置页临时状态（探测结果、提示时间）。CLT 环境缺少 SwiftUIMacros 插件，`@State` 不可用，故用 ObservableObject 承载。
private final class SettingsViewState: ObservableObject {
    @Published var probeStatuses: [HolidaySource: ProbeStatus] = [:]

    func status(for source: HolidaySource) -> ProbeStatus {
        probeStatuses[source] ?? .idle
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var holidays: HolidayStore
    @EnvironmentObject private var loginItem: LoginItemManager
    @EnvironmentObject private var reminders: ReminderStore

    @StateObject private var state = SettingsViewState()

    private static let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = shanghai
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            timeSection
            Divider()
            remindersSection
            Divider()
            holidaySection
            Divider()
            launchSection
        }
        .padding(16)
        .frame(width: 420)
    }

    // MARK: - 提醒事项权限

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("提醒事项")
                .font(.system(size: 12, weight: .semibold))

            HStack(alignment: .top, spacing: 8) {
                Text(reminderStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button("打开系统设置") {
                    reminders.openPrivacySettings()
                }
                .controlSize(.small)
            }

            if let error = reminders.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12))
    }

    private var reminderStatusText: String {
        switch reminders.accessState {
        case .notDetermined: return "尚未请求访问权限"
        case .requesting: return "正在请求访问权限…"
        case .granted: return "已授权，可在月历中查看当天待办"
        case .denied: return "已被拒绝访问，可在系统设置中开启"
        case .restricted: return "受限制，无法访问提醒事项"
        case .writeOnly: return "当前仅允许添加，无法读取列表"
        case .unknown: return "权限状态未知"
        }
    }

    // MARK: - 时间显示

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("时间显示")
                .font(.system(size: 12, weight: .semibold))

            Toggle("24 小时制", isOn: $settings.use24Hour)
            Toggle("显示星期", isOn: $settings.showWeekday)
            Toggle("显示秒", isOn: $settings.showSeconds)

            Text(settings.timeText(for: Date()))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
    }

    // MARK: - 节假日数据源

    private var holidaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("节假日数据源")
                .font(.system(size: 12, weight: .semibold))

            ForEach(HolidaySource.allCases) { source in
                sourceRow(source)
            }

            HStack(spacing: 8) {
                Text("主源")
                    .font(.system(size: 11))
                Picker("", selection: $settings.primarySourceID) {
                    ForEach(HolidaySource.allCases) { source in
                        Text(source.displayName).tag(source.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 160)

                Spacer(minLength: 0)

                Button("立即刷新") {
                    Task { await holidays.refresh(primarySourceID: settings.primarySourceID) }
                }
                .controlSize(.small)
                .disabled(holidays.status.isRefreshing)
            }

            Text(currentStatusText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sourceRow(_ source: HolidaySource) -> some View {
        let status = state.status(for: source)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(.system(size: 11))
                Text(source.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(statusText(for: status))
                .font(.system(size: 10))
                .foregroundStyle(statusColor(for: status))

            Button("测试") {
                Task { await probe(source) }
            }
            .controlSize(.small)
            .disabled(isTesting(source))
        }
    }

    private func probe(_ source: HolidaySource) async {
        state.probeStatuses[source] = .testing
        let result = await holidays.probe(source)
        state.probeStatuses[source] = result.status
    }

    private func isTesting(_ source: HolidaySource) -> Bool {
        if case .testing = state.status(for: source) { return true }
        return false
    }

    private func statusText(for status: ProbeStatus) -> String {
        switch status {
        case .idle: return "未测试"
        case .testing: return "测试中…"
        case let .available(latencyMs): return "可用（\(latencyMs) ms）"
        case let .failed(reason): return "失败：\(reason)"
        }
    }

    private func statusColor(for status: ProbeStatus) -> Color {
        switch status {
        case .failed: return .red
        case .available: return .green
        default: return .secondary
        }
    }

    private var currentStatusText: String {
        var parts = ["当前：\(holidays.status.sourceLabel)"]
        if let updatedAt = holidays.status.updatedAt {
            parts.append("更新于 \(Self.statusTimeFormatter.string(from: updatedAt))")
        }
        if let message = holidays.status.message {
            parts.append(message)
        }
        return parts.joined(separator: " ｜ ")
    }

    // MARK: - 启动

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("启动")
                .font(.system(size: 12, weight: .semibold))

            Toggle("登录时启动", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.setEnabled($0) }
            ))
            .font(.system(size: 12))
            .disabled(!loginItem.isInApplicationsFolder)

            if !loginItem.isInApplicationsFolder {
                Text("当前 App 不在 /Applications，开机自启需要先执行 `./scripts/build.sh install`")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = loginItem.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
