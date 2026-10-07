import Foundation

@MainActor
protocol HabitManaging {
    var habits: [HabitModel] { get }
    var occurrences: [HabitOccurrence] { get }
    func prepare() throws
    func save(_ draft: HabitDraft) throws
    func setStatus(habitId: String, day: LocalDay, status: HabitDayStatus) throws
}
