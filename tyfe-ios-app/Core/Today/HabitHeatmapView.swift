import SwiftUI
import SwiftfulUI

struct HabitHeatmapView: View {
    private static let heatmapGap: CGFloat = 2
    let weeks: [HabitHeatmapWeek]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            Text("\(weeks.first?.days.first?.day.startDate.formatted(.dateTime.month(.abbreviated).year()) ?? "") – \(weeks.last?.days.last?.day.startDate.formatted(.dateTime.month(.abbreviated).year()) ?? "")")
                .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
            HStack(alignment: .top, spacing: Self.heatmapGap) {
                ForEach(weeks) { week in
                    VStack(spacing: Self.heatmapGap) {
                        ForEach(week.days) { day in HabitTileView(day: day, accent: accent) }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Habit completion history, one tile per day")
    }
}
