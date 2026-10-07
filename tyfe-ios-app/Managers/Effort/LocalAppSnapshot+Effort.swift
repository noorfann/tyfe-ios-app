import Foundation

extension LocalAppSnapshot {
    /// Called inside a repository transaction; historical plans and ledger entries are never rewritten.
    mutating func migrateEffort(on day: LocalDay, now: Date) {
        guard effort.migrationDay == nil else { return }
        for activity in activities where activity.type == .checklist && !activity.isArchived {
            let legacyItems = checklistItems.filter { $0.activityId == activity.id }
                .sorted { $0.createdAt < $1.createdAt }
            let completions = checklistItemCompletions.filter {
                $0.activityId == activity.id && $0.localDay == day
            }
            let ticked = Set(completions.map(\.itemId))
            let items = legacyItems.map {
                TodoChecklistItem(id: $0.id, title: $0.title, isCompleted: ticked.contains($0.id))
            }
            let completed = !items.isEmpty && items.allSatisfy(\.isCompleted)
            let taskId = "todo-legacy-" + activity.id
            let completedAt = completed ? (completions.map(\.completedAt).max() ?? now) : nil
            let rewarded = completed || !completions.isEmpty
            effort.tasks.append(TodoTaskModel(
                id: taskId, title: activity.name, projectId: activity.projectId,
                items: items, creditValue: .halfCredit, createdAt: activity.createdAt,
                completedAt: completedAt, hasEarnedAward: rewarded
            ))
            if let completedAt {
                effort.taskHistory.append(TodoCompletionRecord(
                    id: "migration-" + taskId, taskId: taskId, title: activity.name,
                    projectId: activity.projectId, completedAt: completedAt, localDay: day
                ))
            }
        }
        activities = activities.map { activity in
            guard activity.type == .checklist && !activity.isArchived else { return activity }
            return ActivityModel(
                activityId: activity.id, name: activity.name, type: activity.type,
                category: activity.category, iconToken: activity.iconToken, colorToken: activity.colorToken,
                projectId: activity.projectId, recurrence: nil, isArchived: true, createdAt: activity.createdAt
            )
        }
        effort.migrationDay = day
        schemaVersion = 8
    }

    mutating func prepareEffortDays(through today: LocalDay) {
        guard let migrationDay = effort.migrationDay else { return }
        var day = effort.lastPreparedDay ?? migrationDay
        while day.startDate <= today.startDate {
            prepareEffortDay(day, today: today)
            day = day.adding(days: 1)
        }
        // A device time-zone change can move today's boundary behind the saved boundary.
        prepareEffortDay(today, today: today)
        let completedByDay = Dictionary(grouping: focusSessions.filter { $0.state == .completed }, by: \.localDay)
        let changedDays = effort.days.filter { $0.completedSessions != completedByDay[$0.localDay, default: []].count }
        for record in changedDays where record.localDay.startDate < today.startDate {
            prepareEffortDay(record.localDay, today: today)
        }
        effort.lastPreparedDay = today
    }

    private mutating func prepareEffortDay(_ day: LocalDay, today: LocalDay) {
        for habit in effort.habits {
            guard let revision = habit.revision(on: day), !revision.isArchived,
                  revision.schedule.isDue(on: day),
                  !effort.occurrences.contains(where: { $0.habitId == habit.id && $0.localDay == day }) else { continue }
            effort.occurrences.append(HabitOccurrence(
                id: "habit-day-" + habit.id + "-" + day.id,
                habitId: habit.id, localDay: day, title: habit.title,
                projectId: habit.projectId, creditValue: revision.creditValue
            ))
        }
        let plan = dailyPlans.first { $0.localDay == day }
        let planned: Int
        if day.startDate < today.startDate, let recorded = effort.days.first(where: { $0.localDay == day }) {
            planned = recorded.plannedSessions
        } else if let plan {
            planned = plan.planItems.filter { $0.unitKind == .session }.reduce(0) { $0 + $1.plannedSessionCount }
        } else if day.startDate < today.startDate {
            planned = activities.filter {
                $0.type == .session && !$0.isArchived && $0.createdAt < day.adding(days: 1).startDate
                    && ($0.recurrence?.isDue(on: day) ?? false)
            }.reduce(0) { $0 + ($1.recurrence?.defaultSessionCount ?? 0) }
        } else {
            planned = 0
        }
        let completed = focusSessions.filter { $0.localDay == day && $0.state == .completed }.count
        let occurrences = effort.occurrences.filter { $0.localDay == day }
        let required = occurrences.filter { $0.status != .skipped }
        let completedHabits = required.filter { $0.status == .completed }.count
        let hasEffort = planned > 0 || !required.isEmpty
        let successful = hasEffort && completed >= planned && completedHabits == required.count
            && ((planned > 0 && completed > 0) || completedHabits > 0)
        let outcome: EffortDayOutcome = !hasEffort ? .neutral : successful ? .successful
            : day.startDate < today.startDate ? .missed : .pending
        let record = EffortDayRecord(localDay: day, plannedSessions: planned, completedSessions: completed, outcome: outcome)
        if let index = effort.days.firstIndex(where: { $0.localDay == day }) {
            effort.days[index] = record
        } else {
            effort.days.append(record)
        }
        finalizeOccurrences(on: day, before: today)
    }

    func isValidEffortProject(_ id: String?) -> Bool {
        id == nil || projects.contains { $0.id == id && !$0.isArchived }
    }

    mutating func unassignEffort(from projectId: String) {
        for index in effort.tasks.indices where effort.tasks[index].projectId == projectId { effort.tasks[index].projectId = nil }
        for index in effort.habits.indices where effort.habits[index].projectId == projectId { effort.habits[index].projectId = nil }
    }

    private mutating func finalizeOccurrences(on day: LocalDay, before today: LocalDay) {
        guard day.startDate < today.startDate else { return }
        for index in effort.occurrences.indices where effort.occurrences[index].localDay == day && effort.occurrences[index].status == .pending {
            effort.occurrences[index].status = .missed
        }
    }
}
