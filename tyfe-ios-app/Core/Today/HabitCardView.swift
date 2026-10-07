import SwiftUI
import SwiftfulUI

struct HabitCardView: View {
    let habit: HabitModel
    let occurrence: HabitOccurrence?
    let streak: HabitStreakSummary
    let weeks: [HabitHeatmapWeek]
    let scheduleLabel: String
    let onCheck: () -> Void
    let onSkip: () -> Void
    let onDetail: () -> Void

    private var accent: Color { ProjectColorOption.color(for: habit.colorToken) }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(alignment: .top, spacing: TyfeSpacing.small) {
                    HStack(alignment: .top, spacing: TyfeSpacing.small) {
                        Image(systemName: habit.iconToken)
                            .font(.title2).foregroundStyle(accent)
                            .frame(minWidth: 36, minHeight: 44).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                            Text(habit.title).font(TyfeTypography.interfaceStrong)
                            Text(statusLabel).font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .asButton(.press, action: onDetail)
                    .accessibilityLabel("\(habit.title), \(statusLabel), open history")
                    Image(systemName: occurrence?.status == .completed ? "checkmark" : "plus")
                        .font(.headline).frame(width: 44, height: 44)
                        .background(occurrence?.status == .completed ? accent : TyfeEditorialPalette.canvas)
                        .foregroundStyle(occurrence?.status == .completed ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
                        .clipShape(.rect(cornerRadius: TyfeRadius.control))
                        .asButton(.press, action: onCheck)
                        .disabled(occurrence == nil)
                        .accessibilityLabel(occurrence?.status == .completed ? "Undo today's \(habit.title)" : "Complete today's \(habit.title)")
                        .accessibilityValue(statusLabel)
                }
                HabitHeatmapView(weeks: weeks, accent: accent)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TyfeSpacing.small) { badges }
                    VStack(alignment: .leading, spacing: TyfeSpacing.small) { badges }
                }
                if occurrence != nil {
                    Text(occurrence?.status == .skipped ? "Undo skip" : "Skip today")
                        .font(TyfeTypography.caption).frame(minHeight: 44)
                        .asButton(.press, action: onSkip)
                        .accessibilityLabel("\(occurrence?.status == .skipped ? "Undo skip for" : "Skip") \(habit.title)")
                }
            }
        }
    }

    private var statusLabel: String { occurrence?.status.label ?? "Not scheduled today" }

    @ViewBuilder private var badges: some View {
        Label("\(streak.current) streak", systemImage: "flame")
        Label(scheduleLabel, systemImage: "calendar")
    }
}
