import Foundation
import Observation

@Observable
@MainActor
final class HabitManager: HabitManaging {
    let repository: LocalAppRepository
    let clock: FocusClock
    private let calendar: Calendar
    private let logger: LogManager?

    init(
        repository: LocalAppRepository, clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent, logger: LogManager? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.logger = logger
    }

    var currentDay: LocalDay { LocalDay(containing: clock.now, calendar: calendar) }
    var habits: [HabitModel] { repository.snapshot.effort.habits }
    var occurrences: [HabitOccurrence] { repository.snapshot.effort.occurrences }

    func prepare() throws {
        guard repository.snapshot.effort.migrationDay != nil else { throw EffortError.migrationRequired }
        var prepared = repository.snapshot
        prepared.prepareEffortDays(through: currentDay)
        if prepared != repository.snapshot { try repository.transaction { $0 = prepared } }
    }

    func save(_ draft: HabitDraft) throws {
        try prepare()
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let schedule = RepeatSchedule(kind: draft.schedule.kind, weekdays: draft.schedule.weekdays)
        guard !title.isEmpty, repository.snapshot.isValidEffortProject(draft.projectId),
              schedule.kind == .daily || !schedule.weekdays.isEmpty else { throw EffortError.invalidEntry }
        try repository.transaction { snapshot in
            if let id = draft.habitId {
                guard let index = snapshot.effort.habits.firstIndex(where: { $0.id == id }) else { throw EffortError.missingEntry }
                snapshot.effort.habits[index].title = title
                snapshot.effort.habits[index].iconToken = draft.iconToken
                snapshot.effort.habits[index].colorToken = draft.colorToken
                snapshot.effort.habits[index].projectId = draft.projectId
                let tomorrow = currentDay.adding(days: 1)
                snapshot.effort.habits[index].revisions.removeAll { $0.effectiveDay.startDate >= tomorrow.startDate }
                snapshot.effort.habits[index].revisions.append(HabitRevision(
                    effectiveDay: tomorrow, schedule: schedule,
                    creditValue: draft.creditValue, isArchived: draft.isArchived
                ))
            } else {
                snapshot.effort.habits.append(HabitModel(
                    id: "habit-" + UUID().uuidString, title: title, iconToken: draft.iconToken,
                    colorToken: draft.colorToken, projectId: draft.projectId, createdAt: clock.now,
                    revisions: [HabitRevision(effectiveDay: currentDay, schedule: schedule, creditValue: draft.creditValue)]
                ))
            }
            snapshot.prepareEffortDays(through: currentDay)
        }
        logger?.trackEvent(eventName: "Habit_Save", parameters: nil, type: .analytic)
    }

    func setStatus(habitId: String, day: LocalDay, status: HabitDayStatus) throws {
        try prepare()
        guard day == currentDay, [.pending, .completed, .skipped].contains(status) else { throw EffortError.unavailableDay }
        try repository.transaction { snapshot in
            guard let index = snapshot.effort.occurrences.firstIndex(where: { $0.habitId == habitId && $0.localDay == day }) else {
                throw EffortError.unavailableDay
            }
            let occurrence = snapshot.effort.occurrences[index]
            guard occurrence.status != status else { return }
            snapshot.creditLedger.startDay(currentDay, now: clock.now)
            let amount: Decimal = status == .completed ? occurrence.creditValue.creditValue
                : occurrence.status == .completed ? -occurrence.creditValue.creditValue : 0
            if amount != 0 {
                let key = "habit-credit-" + occurrence.id + "-" + String(snapshot.creditLedger.entries.count)
                try snapshot.creditLedger.apply(RewardCreditLedgerEntry(
                    ledgerEntryId: key, source: .habitOccurrence, sourceId: occurrence.id,
                    amount: amount, recordedAt: clock.now, idempotencyKey: key
                ))
            }
            snapshot.effort.occurrences[index].status = status
            snapshot.effort.occurrences[index].completedAt = status == .completed ? clock.now : nil
            snapshot.prepareEffortDays(through: currentDay)
        }
        logger?.trackEvent(eventName: "Habit_Status_Change", parameters: nil, type: .analytic)
    }
}
