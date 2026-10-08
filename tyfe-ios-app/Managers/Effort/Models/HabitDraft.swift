import Foundation

struct HabitDraft {
    var habitId: String?
    var title: String = ""
    var iconToken: String = "leaf.fill"
    var colorToken: String = "teal"
    var projectId: String?
    var schedule = RepeatSchedule(kind: .daily)
    var creditValue: ChecklistCreditValue = .halfCredit
    var isArchived = false

    init(habit: HabitModel? = nil, projectId: String? = nil) {
        habitId = habit?.id
        title = habit?.title ?? ""
        iconToken = habit?.iconToken ?? "leaf.fill"
        colorToken = habit?.colorToken ?? "teal"
        self.projectId = habit?.projectId ?? projectId
        if let revision = habit?.revisions.last {
            schedule = revision.schedule
            creditValue = revision.creditValue
            isArchived = revision.isArchived
        }
    }
}
