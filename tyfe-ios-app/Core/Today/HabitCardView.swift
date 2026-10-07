import SwiftUI
import SwiftfulUI

struct HabitCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let habit: HabitModel
    let occurrence: HabitOccurrence?
    let streak: HabitStreakSummary
    let history: HabitCardHistory
    let scheduleLabel: String
    let onCheck: () -> Void
    let onSkip: () -> Void
    let onDetail: () -> Void

    private var accent: Color { ProjectColorOption.color(for: habit.colorToken) }

    var body: some View {
        TyfeSurfaceView(role: .paper, contentPadding: TyfeSpacing.compactCardInset) {
            VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                HStack(alignment: .center, spacing: TyfeSpacing.relatedGap) {
                    HStack(alignment: .center, spacing: TyfeSpacing.relatedGap) {
                        Image(systemName: habit.iconToken)
                            .font(.headline).foregroundStyle(accent)
                            .frame(width: 24, height: 44).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) {
                            Text(habit.title).font(TyfeTypography.interfaceStrong)
                            Text(statusLabel).font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 44)
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
                HabitCardHistoryView(history: history, accent: accent)
                footer
            }
        }
    }

    private var statusLabel: String { occurrence?.status.label ?? "Not scheduled today" }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedFooter
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TyfeSpacing.relatedGap) {
                        badges
                        skipAction
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    stackedFooter
                }
            }
        }
        .font(TyfeTypography.caption)
    }

    private var stackedFooter: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TyfeSpacing.relatedGap) { badges }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) { badges }
            }
            skipAction
        }
    }

    @ViewBuilder private var skipAction: some View {
        if occurrence != nil {
            Text(occurrence?.status == .skipped ? "Undo skip" : "Skip today")
                .frame(minWidth: 44, minHeight: 44)
                .asButton(.press, action: onSkip)
                .accessibilityLabel("\(occurrence?.status == .skipped ? "Undo skip for" : "Skip") \(habit.title)")
        }
    }

    @ViewBuilder private var badges: some View {
        Label("\(streak.current) streak", systemImage: "flame")
        Label(scheduleLabel, systemImage: "calendar")
    }
}

#Preview("Week") {
    HabitCardPreviewData.card(period: .week).padding(TyfeSpacing.screenInset)
}

#Preview("Month") {
    HabitCardPreviewData.card(period: .month).padding(TyfeSpacing.screenInset)
}

#Preview("Year") {
    HabitCardPreviewData.card(period: .year).padding(TyfeSpacing.screenInset)
}

#Preview("Variety") {
    HabitCardPreviewData.variety(width: 320)
}

#Preview("Variety · 390 pt") {
    HabitCardPreviewData.variety(width: 390)
}

#Preview("Accessibility") {
    ScrollView {
        LazyVStack(spacing: TyfeSpacing.itemGap) {
            ForEach(HabitViewPeriod.allCases) { period in
                HabitCardPreviewData.card(period: period, hasLongLabels: true)
            }
        }
        .padding(TyfeSpacing.screenInset)
    }
    .frame(width: 320)
    .environment(\.dynamicTypeSize, .accessibility3)
}
