import SwiftUI

/// 选中日期的待办列表：按权限状态分支（正常 / 空态 / 引导）。
struct ReminderListView: View {
    let dayKey: String
    let onOpen: () -> Void

    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var holidays: HolidayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider().background(PanelPalette.secondaryText.opacity(0.25))
            content
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var items: [ReminderItem] {
        store.reminders(for: dayKey)
    }

    /// 调休提示（仅选中日）：非官方年份或普通日期返回 nil，标题栏不追加文案。
    private var adjustHint: HolidayAdjustHint? {
        guard let date = MonthGrid.date(forKey: dayKey),
              let holiday = holidays.day(for: date) else { return nil }
        return HolidayAdjustHint.make(name: holidays.name(for: date), isOffDay: holiday.isOffDay)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(Self.title(for: dayKey))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PanelPalette.primaryText)
            if let hint = adjustHint {
                Text(hint.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hint.kind == .offDay ? PanelPalette.offDayBadge : PanelPalette.workDayBadge)
            }
            // 无未完成提醒时不再渲染「0 项」，避免与调休提示并列产生噪音。
            if !items.isEmpty {
                Text("\(items.count) 项")
                    .font(.system(size: 10))
                    .foregroundStyle(PanelPalette.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.accessState {
        case .denied, .restricted, .writeOnly, .unknown:
            guidance
        case .notDetermined, .requesting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("正在请求访问提醒事项…")
                    .font(.system(size: 10))
                    .foregroundStyle(PanelPalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60)
        case .granted:
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var emptyState: some View {
        Text("当日无待办")
            .font(.system(size: 10.5))
            .foregroundStyle(PanelPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 60)
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.accessState == .writeOnly ? "当前仅允许添加提醒事项，无法读取列表。" : "未获得提醒事项访问权限。")
                .font(.system(size: 10.5))
                .foregroundStyle(PanelPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("打开系统设置") {
                store.openPrivacySettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(PanelPalette.termText)
            .focusEffectDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
    }

    private func row(_ item: ReminderItem) -> some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 11))
                    .foregroundStyle(PanelPalette.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let listName = item.listName {
                    Text(listName)
                        .font(.system(size: 9))
                        .foregroundStyle(PanelPalette.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    // MARK: - 标题

    static func title(for dayKey: String) -> String {
        guard let date = MonthGrid.date(forKey: dayKey) else { return dayKey }
        return titleFormatter.string(from: date)
    }

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = MonthGrid.calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()
}
