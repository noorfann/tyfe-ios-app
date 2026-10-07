import Foundation

struct HabitStreakSummary: Equatable {
    let current: Int
    let best: Int

    init(occurrences: [HabitOccurrence], today: LocalDay) {
        var count = 0
        var best = 0
        for occurrence in occurrences.sorted(by: { $0.localDay.startDate < $1.localDay.startDate }) {
            switch occurrence.status {
            case .completed:
                count += 1
                best = max(best, count)
            case .skipped, .unscheduled, .future: break
            case .missed: count = 0
            case .pending:
                if occurrence.localDay.startDate < today.startDate { count = 0 }
            }
        }
        self.current = count
        self.best = best
    }
}
