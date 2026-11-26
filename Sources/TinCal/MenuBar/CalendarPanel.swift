import AppKit
import SwiftUI

/// 面板配色：参考「小历」的深色设计语言。
enum PanelPalette {
    static let background = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let primaryText = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.55)
    static let todayFill = Color(red: 0.90, green: 0.25, blue: 0.20)
    static let termText = Color(red: 1.0, green: 0.68, blue: 0.25)
    static let festivalText = Color(red: 1.0, green: 0.52, blue: 0.52)
    /// 补班（周末上班）角标：红色小旗。
    static let workDayBadge = Color(red: 0.95, green: 0.32, blue: 0.28)
    /// 放假角标（法定节假日 + 调休）：蓝色小旗。
    static let offDayBadge = Color(red: 0.25, green: 0.55, blue: 0.95)
    /// 未完成提醒角标：右下角红色小灯泡，与「今天」红圈同色系。
    static let reminderDot = Color(red: 0.98, green: 0.42, blue: 0.35)
}

/// 面板尺寸（供 StatusBarController 的手势动画共用）。
enum PanelMetrics {
    static let width: CGFloat = 320
    static let padding: CGFloat = 12
    static let pageWidth = width - padding * 2
    private static let spacing: CGFloat = 6
    /// 单日格子高度（与 DayCell 的 `.frame(height:)` 一致）。
    static let cellHeight: CGFloat = 44
    /// 月历网格按最多行数预留，保证 5 行 / 6 行月份视觉位置一致。
    static let maxGridRows = 6
    static let gridHeight = cellHeight * CGFloat(maxGridRows)
    /// 头部（月份标题 + 翻页 / 今天按钮）高度。
    static let headerHeight: CGFloat = 24
    /// 星期行高度。
    static let weekdayRowHeight: CGFloat = 14
    /// 提醒区域固定高度：各态（列表 / 空态 / 引导）切换时高度一致。
    static let reminderAreaHeight: CGFloat = 186
    /// 折叠态总高（未选中日期）：内容贴顶，面板不再上下留白。
    static let collapsedPanelHeight = padding * 2 + headerHeight + spacing + weekdayRowHeight + spacing + gridHeight + spacing
    /// 展开态总高（选中某天）：折叠态 + 底部提醒区。
    static let panelHeight = collapsedPanelHeight + reminderAreaHeight
}

/// 面板翻月与选中状态。由 StatusBarController 持有，便于触控板手势与面板共享。
final class CalendarViewState: ObservableObject {
    @Published var anchor = MonthGrid.addingMonths(0, to: Date())
    /// 翻页动画期间提前显示的目标月份标题；nil 时用 anchor。
    @Published var titleAnchor: Date?
    /// 手势跟手偏移（横向像素），松手后归零。
    @Published var dragOffset: CGFloat = 0
    /// 高亮选中的日期键（`yyyy-MM-dd`）；nil 表示无选中框。
    @Published var selectedDayKey: String?
    /// 已展开待办列表的日期键；nil 表示不显示提醒区域。
    @Published var expandedDayKey: String?

    /// 翻月 / 翻页时清空选中与展开状态，避免列表停留在其它月份。
    func resetSelection() {
        selectedDayKey = nil
        expandedDayKey = nil
    }
}

/// 菜单栏弹出的月历面板。
struct CalendarPanel: View {
    @ObservedObject var state: CalendarViewState

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var holidays: HolidayStore
    @EnvironmentObject private var reminders: ReminderStore

    private let weekdaySymbols = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// 实际展示提醒区的日期键：仅在选中且当天存在未完成提醒时为非 nil。
    /// 无提醒的日期不展开，避免出现大块留白；刷新后提醒被清空也会自动回落折叠态。
    private var activeReminderDayKey: String? {
        guard let key = state.expandedDayKey, !reminders.reminders(for: key).isEmpty else { return nil }
        return key
    }

    /// 有未完成提醒的日期键集合（含前月 / 后月页），供 DayCell 亮灯泡。
    /// 未获授权时恒为空集，避免泄漏「有权限但看不到内容」的日期信息。
    private var reminderDayKeys: Set<String> {
        reminders.canShowReminders ? Set(reminders.remindersByDay.keys) : []
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            weekdayRow
            HStack(alignment: .top, spacing: 0) {
                monthGrid(for: MonthGrid.addingMonths(-1, to: state.anchor))
                monthGrid(for: state.anchor)
                monthGrid(for: MonthGrid.addingMonths(1, to: state.anchor))
            }
            .offset(x: -PanelMetrics.pageWidth + state.dragOffset)
            .frame(width: PanelMetrics.pageWidth, alignment: .leading)
            .clipped()

            reminderArea
            // 吸收折叠态富余高度，使内容贴顶、空白只可能落在底部。
            Spacer(minLength: 0)
        }
        .padding(PanelMetrics.padding)
        // 折叠态只包月历区；选中某天时从底部追加提醒区。
        .frame(
            width: PanelMetrics.width,
            height: activeReminderDayKey == nil ? PanelMetrics.collapsedPanelHeight : PanelMetrics.panelHeight,
            alignment: .top
        )
        .background(PanelPalette.background)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 提醒区域

    @ViewBuilder
    private var reminderArea: some View {
        if let dayKey = activeReminderDayKey {
            // 点击条目直达系统「提醒事项」App，不做详情层，减少操作层级。
            ReminderListView(dayKey: dayKey) {
                reminders.openRemindersApp()
            }
            .frame(height: PanelMetrics.reminderAreaHeight)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func toggleSelection(for day: MonthDay) {
        let key = MonthGrid.key(for: day.date)
        // 始终高亮点击的日期；再次点击同一天则收起其待办列表。
        state.selectedDayKey = key
        if state.expandedDayKey == key {
            state.expandedDayKey = nil
        } else {
            state.expandedDayKey = key
            // 展开查看前强制刷新一次（跳过 30s 节流），保证看到的是最新待办。
            Task { await reminders.refreshIfNeeded(force: true) }
        }
    }

    // MARK: - 月历网格

    private func monthGrid(for anchor: Date) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(MonthGrid.days(for: anchor)) { day in
                let key = MonthGrid.key(for: day.date)
                DayCell(
                    day: day,
                    hasReminder: reminderDayKeys.contains(key),
                    isSelected: state.selectedDayKey == key,
                    onTap: { toggleSelection(for: day) }
                )
            }
        }
        .frame(width: PanelMetrics.pageWidth)
        // 网格区定高顶对齐：5 行月份的多余空间落在网格下方，各月顶部基准线一致。
        .frame(height: PanelMetrics.gridHeight, alignment: .top)
    }

    // MARK: - 头部

    private var header: some View {
        ZStack {
            Text(MonthGrid.monthTitle(for: state.titleAnchor ?? state.anchor))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(PanelPalette.primaryText)

            HStack(spacing: 10) {
                Button {
                    state.anchor = MonthGrid.addingMonths(-1, to: state.anchor)
                    state.resetSelection()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(PanelPalette.secondaryText)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()

                Spacer(minLength: 0)

                Button {
                    state.anchor = MonthGrid.addingMonths(1, to: state.anchor)
                    state.resetSelection()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PanelPalette.secondaryText)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()

                Button("今天") {
                    state.anchor = MonthGrid.addingMonths(0, to: Date())
                    state.resetSelection()
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .foregroundStyle(PanelPalette.secondaryText)
                .font(.system(size: 11))
            }
        }
    }

    // MARK: - 星期行

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(PanelPalette.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
