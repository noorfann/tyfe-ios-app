import SwiftUI
import SwiftfulUI

struct HabitHeatmapView: View {
    let weeks: [HabitHeatmapWeek]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("\(weeks.first?.days.first?.day.startDate.formatted(.dateTime.month(.abbreviated).year()) ?? "") – \(weeks.last?.days.last?.day.startDate.formatted(.dateTime.month(.abbreviated).year()) ?? "")")
                .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
            HStack(alignment: .top, spacing: 2) {
                ForEach(weeks) { week in
                    VStack(spacing: 2) {
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
