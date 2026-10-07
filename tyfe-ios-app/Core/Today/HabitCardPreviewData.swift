import SwiftUI

@MainActor
enum HabitCardPreviewData {
    static let today = LocalDay(year: 2026, month: 10, day: 7, timeZoneIdentifier: "Asia/Jakarta")

    static func card(
        period: HabitViewPeriod, isNew: Bool = false, isArchived: Bool = false,
        hasLongLabels: Bool = false, isScheduledToday: Bool = true
    ) -> HabitCardView {
        let createdDay = today.adding(days: isNew ? 0 : -60)
        let habit = HabitModel(
            id: "preview-\(period.rawValue)-\(isNew)-\(isArchived)",
            title: hasLongLabels ? "Read a chapter and write a short reflection before breakfast"
                : isNew ? "A new habit" : isArchived ? "Archived reading habit" : "Read a chapter",
            iconToken: "book.fill", colorToken: "teal", createdAt: createdDay.startDate,
            revisions: [HabitRevision(effectiveDay: createdDay, schedule: .init(kind: .daily), creditValue: .halfCredit, isArchived: isArchived)]
        )
        let occurrence: HabitOccurrence? = isArchived || !isScheduledToday ? nil : HabitOccurrence(
            id: "preview-today", habitId: habit.id, localDay: today,
            title: habit.title, creditValue: .halfCredit
        )
        return HabitCardView(
            habit: habit, occurrence: occurrence, streak: HabitStreakSummary(occurrences: [], today: today),
            history: history(period: period, createdDay: createdDay, isArchived: isArchived, isScheduledToday: isScheduledToday),
            scheduleLabel: isArchived ? "Archived" : hasLongLabels ? "Monday, Tuesday, Wednesday, Thursday, Friday"
                : isScheduledToday ? "Every day" : "Monday and Friday",
            onCheck: {}, onSkip: {}, onDetail: {}
        )
    }

    static func variety(width: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: TyfeSpacing.itemGap) {
                ForEach(HabitViewPeriod.allCases) { period in
                    card(period: period)
                    card(period: period, hasLongLabels: true)
                    card(period: period, isArchived: true)
                    card(period: period, isScheduledToday: false)
                }
                card(period: .month, isNew: true)
            }
            .padding(TyfeSpacing.screenInset)
        }
        .frame(width: width)
    }

    static func history(
        period: HabitViewPeriod, createdDay: LocalDay, isArchived: Bool = false, isScheduledToday: Bool = true
    ) -> HabitCardHistory {
        let first: LocalDay
        let count: Int
        switch period {
        case .week:
            first = today.adding(days: -2)
            count = 7
        case .month:
            first = LocalDay(year: 2026, month: 9, day: 28, timeZoneIdentifier: today.timeZoneIdentifier)
            count = 35
        case .year:
            first = LocalDay(year: 2025, month: 12, day: 29, timeZoneIdentifier: today.timeZoneIdentifier)
            count = 371
        }
        let days = (0..<count).map { offset -> HabitGridDay in
            let day = first.adding(days: offset)
            let status: HabitDayStatus
            if day.startDate > today.startDate {
                status = .future
            } else if day.startDate < createdDay.startDate || (isArchived && day.startDate >= today.adding(days: -7).startDate) {
                status = .unscheduled
            } else if day == today {
                status = isScheduledToday ? .pending : .unscheduled
            } else {
                status = offset.isMultiple(of: 5) ? .skipped : offset.isMultiple(of: 3) ? .missed : .completed
            }
            return HabitGridDay(day: day, status: status, isToday: day == today, isInMonth: day.year == today.year && day.month == today.month)
        }
        return HabitCardHistory(period: period, anchorDay: today, days: days)
    }
}
