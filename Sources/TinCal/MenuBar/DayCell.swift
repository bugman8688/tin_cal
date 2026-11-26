import SwiftUI

/// 月历单日格子：公历日 + 节气/农历 + 休班角标 + 未完成提醒灯泡；支持单击选中。
struct DayCell: View {
    let day: MonthDay
    /// 当日存在未完成提醒时，右下角亮红色小灯泡（由 Panel 统一注入，未授权恒为 false）。
    var hasReminder: Bool = false
    var isSelected: Bool = false
    var onTap: (() -> Void)?
    @EnvironmentObject private var holidays: HolidayStore

    var body: some View {
        let offDay = holidays.isOffDay(for: day.date)
        let term = SolarTerm.name(for: day.date)
        let lunarLabel = LunarCalendar.dayLabel(for: day.date)
        let subtitle = term ?? lunarLabel
        let isMonthLabel = term == nil && lunarLabel.hasSuffix("月")

        VStack(spacing: 0) {
            Text("\(day.dayNumber)")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(day.isToday ? Color.white : PanelPalette.primaryText)
                .frame(width: 28, height: 22)
                .background {
                    if day.isToday {
                        Circle()
                            .fill(PanelPalette.todayFill)
                            .frame(width: 26, height: 26)
                    }
                }

            Text(subtitle)
                .font(.system(size: 10.5))
                .foregroundStyle(subtitleColor(term: term, isMonthLabel: isMonthLabel))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .overlay(alignment: .topTrailing) { badge(for: offDay) }
        // 灯泡放右下角，与右上角旗标互不遮挡；随格子 opacity 一起变淡。
        .overlay(alignment: .bottomTrailing) {
            if hasReminder {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(PanelPalette.reminderDot)
                    .padding(2)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                    .padding(1)
            }
        }
        .opacity(day.isInMonth ? 1 : 0.22)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private func subtitleColor(term: String?, isMonthLabel: Bool) -> Color {
        if term != nil { return PanelPalette.termText }
        return isMonthLabel ? PanelPalette.festivalText : PanelPalette.secondaryText
    }

    @ViewBuilder
    private func badge(for offDay: Bool?) -> some View {
        if let offDay {
            // 红色小旗 = 补班，蓝色小旗 = 放假（法定节假日 + 调休）。
            Image(systemName: "flag.fill")
                .font(.system(size: 7))
                .foregroundStyle(offDay ? PanelPalette.offDayBadge : PanelPalette.workDayBadge)
                .padding(3)
        }
    }
}
