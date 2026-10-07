# Phase 2: Session, To Do, and Habit

Today opens on Session. Its top selector switches between Session, To Do, and Habit while retaining the selected Space. The bottom navigation and Session timer, recurrence, daily planning, and historical navigation remain in place. The add action follows the selected page.

To Dos persist until completed and have no due dates. Optional checklist steps do not award credits; completing every step completes the task. Each task earns its configured whole-entry award once. Same-day undo reverses the exact recorded award, and insufficient balance rejects the complete edit. Reopening on a later day retains completion history and the lifetime award flag. Editing steps follows the same rules.

Habits support daily or selected-weekday schedules. Each due date has one persistent occurrence with a credit-value and name snapshot. Only today's due occurrence can be completed, undone, or skipped. Skips are excused and earn no credits. Existing schedule, credit-value, and archive edits take effect tomorrow; names, icons, colors, and Space assignments update immediately. Archived Habits can be edited to restore them from tomorrow.

Cards show a six-month heatmap, schedule, and current streak. Details show full history, current and best streaks, and a read-only monthly calendar. Heatmap cells expose date and status to accessibility services; the monthly calendar becomes a status list at accessibility text sizes.

A successful day requires the planned Session count and every non-skipped due Habit, with at least one qualifying completion. To Dos do not count. Extra Sessions cannot replace Habits. Days with no required effort are neutral; neutral days and skipped Habit occurrences neither increment nor break their streaks. Missed required days retain the existing freeze policy. Circles continue sharing Sessions only, and credits still expire daily.

## Persistence and migration

Snapshot schema 8 adds To Dos, completion history, Habit revisions, dated occurrences, daily outcomes, and local streak baselines. Completion state and credit ledger changes are saved in the same repository transaction. The candidate snapshot is published only after persistence succeeds.

The first preparation converts active legacy checklists to To Dos, preserving their contents, Spaces, and current-day ticks. Legacy activities are archived with recurrence removed. Existing historical plans, checklist records, ledger entries, and streak achievements remain intact. Fully checked tasks are completed without a new award; tasks with any migrated tick cannot earn another award. Untouched migrated tasks default to 0.5 credits. A persisted migration marker makes retries and relaunches idempotent.

Before the first migrated file is saved, persistence writes the original bytes to a sibling file with the suffix `.pre-phase2-backup`. A failed load or save cannot publish migration or overwrite the original work. Preparation can be retried from Today. Future snapshot versions are rejected.

For a manual rollback, close the app, preserve a copy of the current snapshot, and restore the backup to the original snapshot path before using the previous app version. The backup is a recovery point from before migration; restoring it discards subsequent Phase 2 changes. Historical streak storage is retained separately and is not rewritten.

## Verification

Focused test source covers migration and relaunch, failed persistence and retry, backup preservation, persistent checklist ticks, auto-completion, reopening, award deduplication, insufficient-balance undo, schedules and skips, future-effective edits, neutral days, freezes, independent Session/Habit requirements, selector navigation, shared Space filtering, history, empty data, and accessible calendar status labels.

Repository policy permits static inspection, Swift syntax parsing, and non-rewriting SwiftLint by default. Builds, test execution, simulator checks, and visual validation at different Dynamic Type sizes require an explicit request. These runtime checks have not been executed for this implementation.
