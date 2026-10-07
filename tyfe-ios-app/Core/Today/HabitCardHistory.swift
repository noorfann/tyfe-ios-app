import Foundation

struct HabitCardHistory {
    let period: HabitViewPeriod
    let anchorDay: LocalDay
    let days: [HabitGridDay]
    let weeks: [HabitHeatmapWeek]
    let visibleDays: [HabitGridDay]

    init(period: HabitViewPeriod, anchorDay: LocalDay, days: [HabitGridDay]) {
        self.period = period
        self.anchorDay = anchorDay
        self.days = days
        weeks = period == .year ? stride(from: 0, to: days.count, by: 7).map { start in
            HabitHeatmapWeek(days: Array(days[start..<min(start + 7, days.count)]))
        } : []
        visibleDays = days.filter { day in
            switch period {
            case .week: true
            case .month: day.isInMonth
            case .year: day.day.year == anchorDay.year
            }
        }
    }

    var title: String {
        switch period {
        case .week:
            guard let first = days.first, let last = days.last else { return "This week" }
            return "\(dateLabel(first.day, style: .dateTime.month(.abbreviated).day())) – \(dateLabel(last.day, style: .dateTime.month(.abbreviated).day().year()))"
        case .month: return dateLabel(anchorDay, style: .dateTime.month(.wide).year())
        case .year: return dateLabel(anchorDay, style: .dateTime.year())
        }
    }

    var initialScrollFraction: Double {
        guard let index = weeks.firstIndex(where: { $0.days.contains(where: \.isToday) }) else { return 0 }
        return Double(index) / Double(max(weeks.count - 1, 1))
    }

    func dateLabel(_ day: LocalDay, style: Date.FormatStyle) -> String {
        var localStyle = style
        localStyle.calendar = Calendar(identifier: .gregorian)
        localStyle.timeZone = TimeZone(identifier: day.timeZoneIdentifier) ?? .current
        return day.startDate.formatted(localStyle)
    }
}
