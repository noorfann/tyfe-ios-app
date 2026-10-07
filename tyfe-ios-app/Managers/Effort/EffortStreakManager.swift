import Foundation
import Observation

/// Daily outcomes are authoritative after migration. The legacy event store remains untouched.
@Observable
@MainActor
final class EffortStreakManager {
    private let repository: LocalAppRepository
    private let clock: FocusClock
    private let calendar: Calendar
    private let logger: LogManager?
    private(set) var revision = 0

    init(
        repository: LocalAppRepository, clock: FocusClock = SystemFocusClock(),
        calendar: Calendar = .autoupdatingCurrent, logger: LogManager? = nil
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.logger = logger
    }

    var today: LocalDay { LocalDay(containing: clock.now, calendar: calendar) }
    var days: [EffortDayRecord] {
        _ = revision
        return repository.snapshot.effort.days
    }

    func hasBaseline(userId: String) -> Bool {
        repository.snapshot.effort.streakBaselines.contains { $0.userId == userId }
    }

    func seed(userId: String, legacy: CurrentStreakData, events: [StreakEvent], freezes: [StreakFreeze]) throws {
        guard !hasBaseline(userId: userId), let boundary = repository.snapshot.effort.migrationDay else { return }
        let oldEvents = events.filter { $0.dateCreated < boundary.adding(days: 1).startDate }
        let earnedToday = oldEvents.contains { !$0.isFreeze && $0.dateCreated >= boundary.startDate }
        let baseline = EffortStreakBaseline(
            userId: userId, boundaryDay: boundary, current: legacy.currentStreak ?? 0,
            longest: legacy.longestStreak ?? 0, startedAt: legacy.dateStreakStart,
            lastEventAt: legacy.dateLastEvent, totalEvents: legacy.totalEvents ?? oldEvents.count,
            grandfatheredToday: earnedToday,
            freezes: freezes.map { EffortFreeze(id: $0.id, earnedAt: $0.dateEarned, usedAt: $0.dateUsed, expiresAt: $0.dateExpires) },
            events: oldEvents.map { EffortLegacyEvent(id: $0.id, date: $0.dateCreated, timeZone: $0.timezone, isFreeze: $0.isFreeze, freezeId: $0.freezeId) }
        )
        try repository.transaction { $0.effort.streakBaselines.append(baseline) }
        try reconcile()
        logger?.trackEvent(eventName: "Effort_StreakMigration_Success", parameters: nil, type: .analytic)
    }

    func reconcile() throws {
        var next = repository.snapshot
        next.prepareEffortDays(through: today)
        for index in next.effort.streakBaselines.indices {
            var baseline = next.effort.streakBaselines[index]
            for freezeIndex in baseline.freezes.indices {
                if let day = baseline.freezes[freezeIndex].protectedDay,
                   next.effort.days.contains(where: { $0.localDay == day && $0.outcome == .successful }) {
                    baseline.freezes[freezeIndex].usedAt = nil
                    baseline.freezes[freezeIndex].protectedDay = nil
                }
            }
            // Today's milestone can be undone; finalized days and consumed freezes are immutable.
            baseline.freezes.removeAll { $0.earningDay == today && $0.usedAt == nil }
            _ = calculate(baseline: &baseline, days: next.effort.days, awardFreezes: true)
            next.effort.streakBaselines[index] = baseline
        }
        if next != repository.snapshot {
            next.effort.updatedAt = clock.now
            try repository.transaction { $0 = next }
        }
        revision += 1
    }

    func data(userId: String, fallback: CurrentStreakData) -> CurrentStreakData {
        _ = revision
        guard var baseline = repository.snapshot.effort.streakBaselines.first(where: { $0.userId == userId }) else { return fallback }
        let result = calculate(baseline: &baseline, days: repository.snapshot.effort.days, awardFreezes: false)
        let allEvents = events(userId: userId)
        let available = baseline.freezes.filter { $0.usedAt == nil && ($0.expiresAt.map { $0 > clock.now } ?? true) }.map(\.model)
        return CurrentStreakData(
            streakKey: Constants.streakKey, userId: userId, currentStreak: result.current,
            longestStreak: result.best, dateLastEvent: allEvents.last?.dateCreated ?? baseline.lastEventAt,
            lastEventTimezone: today.timeZoneIdentifier, dateStreakStart: result.start,
            totalEvents: baseline.totalEvents + result.newSuccesses,
            freezesAvailable: available, freezesAvailableCount: available.count,
            dateCreated: allEvents.first?.dateCreated, dateUpdated: repository.snapshot.effort.updatedAt,
            eventsRequiredPerDay: 1, todayEventCount: allEvents.contains { !$0.isFreeze && $0.dateCreated >= today.startDate } ? 1 : 0,
            recentEvents: Array(allEvents.suffix(60))
        )
    }

    func events(userId: String) -> [StreakEvent] {
        _ = revision
        guard let baseline = repository.snapshot.effort.streakBaselines.first(where: { $0.userId == userId }) else { return [] }
        let days = repository.snapshot.effort.days.filter { $0.localDay.startDate >= baseline.boundaryDay.startDate }
        var events = baseline.events.map(\.model)
        for day in days {
            if day.outcome == .successful, !(day.localDay == baseline.boundaryDay && baseline.grandfatheredToday) {
                events.append(StreakEvent(
                    id: "effort-success-" + day.id, dateCreated: day.localDay.startDate,
                    timezone: day.localDay.timeZoneIdentifier, metadata: ["source": .string("successful_day")]
                ))
            } else if day.outcome == .missed,
                      let freeze = baseline.freezes.first(where: { $0.protectedDay == day.localDay }) {
                events.append(StreakEvent(
                    id: "effort-freeze-" + day.id, dateCreated: day.localDay.startDate,
                    timezone: day.localDay.timeZoneIdentifier, isFreeze: true, freezeId: freeze.id
                ))
            }
        }
        return events.sorted { $0.dateCreated < $1.dateCreated }
    }

    func freezes(userId: String) -> [StreakFreeze] {
        repository.snapshot.effort.streakBaselines.first { $0.userId == userId }?.freezes.map(\.model) ?? []
    }

    private struct Calculation {
        var current: Int
        var best: Int
        var start: Date?
        var newSuccesses = 0
    }

    private func calculate(baseline: inout EffortStreakBaseline, days: [EffortDayRecord], awardFreezes: Bool) -> Calculation {
        var result = Calculation(current: baseline.current, best: baseline.longest, start: baseline.startedAt)
        for day in days.sorted(by: { $0.localDay.startDate < $1.localDay.startDate }) {
            guard day.localDay.startDate >= baseline.boundaryDay.startDate else { continue }
            if day.localDay == baseline.boundaryDay && baseline.grandfatheredToday { continue }
            switch day.outcome {
            case .successful:
                if result.current == 0 { result.start = day.localDay.startDate }
                result.current += 1
                result.newSuccesses += 1
                result.best = max(result.best, result.current)
                if awardFreezes { awardFreeze(for: day.localDay, calculation: result, baseline: &baseline) }
            case .missed:
                let protected = baseline.freezes.contains { $0.protectedDay == day.localDay }
                if !protected, result.current > 0, awardFreezes,
                   let index = baseline.freezes.firstIndex(where: {
                       $0.usedAt == nil && ($0.earnedAt ?? .distantPast) < day.localDay.adding(days: 1).startDate
                           && ($0.expiresAt.map { $0 > day.localDay.startDate } ?? true)
                   }) {
                    baseline.freezes[index].usedAt = day.localDay.startDate
                    baseline.freezes[index].protectedDay = day.localDay
                } else if !protected {
                    result.current = 0
                    result.start = nil
                }
            case .neutral, .pending: break
            }
        }
        return result
    }

    private func awardFreeze(for day: LocalDay, calculation: Calculation, baseline: inout EffortStreakBaseline) {
        guard calculation.current.isMultiple(of: StreakFreezePolicy.milestoneInterval), let start = calculation.start else { return }
        let id = "effort-" + StreakFreezePolicy.freezeId(streakStart: start, milestone: calculation.current)
        guard !baseline.freezes.contains(where: { $0.id == id }),
              baseline.freezes.filter({
                  ($0.usedAt.map { $0 >= day.startDate } ?? true) && ($0.earnedAt ?? .distantPast) <= day.startDate
                      && ($0.expiresAt.map { $0 > day.startDate } ?? true)
              }).count
                < StreakFreezePolicy.maximumAvailableFreezes else { return }
        baseline.freezes.append(EffortFreeze(id: id, earnedAt: day.startDate, expiresAt: nil, earningDay: day))
    }
}
