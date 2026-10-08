import SwiftUI

struct HabitCardHistoryView: View {
    private static let heatmapGap: CGFloat = 2
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let history: HabitCardHistory
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) {
            Text(history.title)
                .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
            if dynamicTypeSize.isAccessibilitySize {
                accessibleHistory
            } else {
                switch history.period {
                case .week: weekRow
                case .month: monthGrid
                case .year: yearHeatmap
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Habit \(history.period.title.lowercased()) history")
        .accessibilityIdentifier("habit-card-history-\(history.period.rawValue)")
    }

    private var weekRow: some View {
        HStack(alignment: .top, spacing: TyfeSpacing.relatedGap) {
            ForEach(history.days) { day in
                VStack(spacing: TyfeSpacing.tightGap) {
                    Text(RepeatSchedule.weekdayShortName(forISO: RepeatSchedule.isoWeekday(for: day.day) ?? 1))
                        .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .accessibilityHidden(true)
                    numberedTile(day)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TyfeSpacing.tightGap), count: 7), spacing: TyfeSpacing.tightGap) {
            ForEach(1...7, id: \.self) { weekday in
                Text(RepeatSchedule.weekdayShortName(forISO: weekday))
                    .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .accessibilityHidden(true)
            }
            ForEach(history.days) { day in
                numberedTile(day).opacity(day.isInMonth ? 1 : 0.2)
            }
        }
    }

    private func numberedTile(_ day: HabitGridDay) -> some View {
        HabitTileView(day: day, accent: accent)
            .frame(width: 28, height: 28)
            .overlay {
                Text(String(day.day.day))
                    .font(TyfeTypography.caption)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(day.status == .completed ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
                    .accessibilityHidden(true)
            }
    }

    private var yearHeatmap: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Self.heatmapGap) {
                ForEach(history.weeks) { week in
                    VStack(spacing: Self.heatmapGap) {
                        Color.clear.frame(height: 20)
                            .overlay(alignment: .leading) {
                                if let first = week.days.first(where: { $0.day.day == 1 && $0.day.year == history.anchorDay.year }) {
                                    Text(history.dateLabel(first.day, style: .dateTime.month(.abbreviated)))
                                        .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                                        .fixedSize().accessibilityHidden(true)
                                }
                            }
                        ForEach(week.days) { day in
                            HabitTileView(day: day, accent: accent)
                                .frame(width: 10, height: 10)
                                .opacity(day.day.year == history.anchorDay.year ? 1 : 0)
                                .accessibilityHidden(day.day.year != history.anchorDay.year)
                        }
                    }
                    .frame(width: 10)
                }
            }
        }
        .defaultScrollAnchor(UnitPoint(x: CGFloat(history.initialScrollFraction), y: 0), for: .initialOffset)
        .id(history.anchorDay.year)
        .accessibilityHint("Scroll horizontally to explore the year")
    }

    @ViewBuilder private var accessibleHistory: some View {
        if history.period == .year {
            LazyVStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                ForEach(1...12, id: \.self) { month in
                    let days = history.visibleDays.filter { $0.day.month == month }
                    if let first = days.first {
                        Text(history.dateLabel(first.day, style: .dateTime.month(.wide)))
                            .font(TyfeTypography.interfaceStrong).accessibilityAddTraits(.isHeader)
                        accessibleDays(days)
                    }
                }
            }
        } else {
            accessibleDays(history.visibleDays)
        }
    }

    private func accessibleDays(_ days: [HabitGridDay]) -> some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            ForEach(days) { day in
                Text("\(history.dateLabel(day.day, style: .dateTime.month(.abbreviated).day())): \(day.status.label)\(day.isToday ? " · Today" : "")")
                    .font(TyfeTypography.interface).accessibilityLabel(day.accessibilityLabel)
            }
        }
    }
}

#Preview("Variety") {
    ScrollView {
        VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
            ForEach(HabitViewPeriod.allCases) { period in
                HabitCardHistoryView(
                    history: HabitCardPreviewData.history(period: period, createdDay: HabitCardPreviewData.today.adding(days: -60)),
                    accent: TyfeEditorialPalette.teal
                )
            }
        }
        .padding(TyfeSpacing.screenInset)
    }
}
