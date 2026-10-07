import SwiftUI
import SwiftfulUI

struct HabitFormView: View {
    @Binding var draft: HabitDraft
    let projects: [ProjectModel]
    let onSave: () -> Void
    private static let icons = ["leaf.fill", "book.fill", "figure.walk", "drop.fill", "heart.fill", "pencil"]

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    TyfeTextFieldView(placeholder: "Name your habit", text: $draft.title)
                        .accessibilityIdentifier("habit-title-field")
                    EffortSpacePicker(projectId: $draft.projectId, projects: projects)
                    Picker("Icon", selection: $draft.iconToken) {
                        ForEach(Self.icons, id: \.self) { icon in Label(iconTitle(icon), systemImage: icon).tag(icon) }
                    }
                    Picker("Color", selection: $draft.colorToken) {
                        ForEach(ProjectColorOption.allCases) { color in Text(color.title).tag(color.rawValue) }
                    }
                    EffortCreditPicker(creditValue: $draft.creditValue)
                }
            }
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    Picker("Repeat", selection: $draft.schedule.kind) {
                        Text("Every day").tag(ActivityRecurrenceKind.daily)
                        Text("Selected weekdays").tag(ActivityRecurrenceKind.weekly)
                    }
                    .pickerStyle(.menu)
                    if draft.schedule.kind == .weekly {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68))], spacing: TyfeSpacing.small) {
                            ForEach(1...7, id: \.self) { weekday in weekdayButton(weekday) }
                        }
                    }
                    if draft.habitId != nil {
                        Toggle("Archive from tomorrow", isOn: $draft.isArchived)
                        Text("Schedule, credits, and archive changes begin tomorrow. Today's record stays intact.")
                            .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                    }
                }
            }
            TyfeActionButtonView(
                title: "Save Habit", systemImage: "checkmark",
                isEnabled: !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && (draft.schedule.kind == .daily || !draft.schedule.weekdays.isEmpty),
                onTap: onSave
            )
        }
    }

    private func weekdayButton(_ weekday: Int) -> some View {
        let selected = draft.schedule.weekdays.contains(weekday)
        return Text(ActivityRecurrenceModel.weekdayShortName(forISO: weekday))
            .font(TyfeTypography.interfaceStrong)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? TyfeEditorialPalette.teal : TyfeEditorialPalette.canvas)
            .foregroundStyle(selected ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
            .clipShape(.rect(cornerRadius: TyfeRadius.control))
            .asButton(.press) {
                if selected { draft.schedule.weekdays.removeAll { $0 == weekday } } else {
                    draft.schedule.weekdays.append(weekday)
                    draft.schedule.weekdays.sort()
                }
            }
            .accessibilityLabel(weekdayName(weekday))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func weekdayName(_ day: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day - 1]
    }

    private func iconTitle(_ icon: String) -> String {
        switch icon {
        case "book.fill": return "Reading"
        case "figure.walk": return "Movement"
        case "drop.fill": return "Water"
        case "heart.fill": return "Health"
        case "pencil": return "Writing"
        default: return "Growth"
        }
    }
}
