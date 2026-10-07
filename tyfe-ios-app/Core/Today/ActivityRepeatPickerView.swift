import SwiftUI
import SwiftfulUI

enum ActivityRepeatChoice: Hashable {
    case never
    case everyDay
    case certainDays
}

struct ActivityRepeatDraft: Equatable {
    var choice: ActivityRepeatChoice
    var weekdays: Set<Int>

    init(recurrence: ActivityRecurrenceModel?) {
        guard let recurrence else {
            choice = .never
            weekdays = []
            return
        }
        switch recurrence.kind {
        case .daily:
            choice = .everyDay
            weekdays = []
        case .weekly:
            choice = .certainDays
            weekdays = Set(recurrence.weekdays)
        }
    }

    var isValid: Bool {
        choice != .certainDays || !weekdays.isEmpty
    }

    func recurrence(defaultSessionCount: Int) -> ActivityRecurrenceModel? {
        switch choice {
        case .never:
            return nil
        case .everyDay:
            return ActivityRecurrenceModel(
                kind: .daily,
                defaultSessionCount: defaultSessionCount
            )
        case .certainDays:
            guard !weekdays.isEmpty else { return nil }
            return ActivityRecurrenceModel(
                kind: .weekly,
                weekdays: weekdays.sorted(),
                defaultSessionCount: defaultSessionCount
            )
        }
    }
}

struct ActivityRepeatPickerView: View {

    @Binding var draft: ActivityRepeatDraft

    private static let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private static let weekdayFullNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                Text("REPEAT")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.relatedGap) {
                    choiceButton(.never, title: "Never")
                    choiceButton(.everyDay, title: "Every day")
                    choiceButton(.certainDays, title: "Certain days")
                }

                if draft.choice == .certainDays {
                    weekdayPicker
                }

                Text(footnote)
                    .font(TyfeTypography.caption)
                    .foregroundStyle(
                        draft.isValid ? TyfeEditorialPalette.muted : TyfeEditorialPalette.warning
                    )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Repeat")
    }

    private var footnote: String {
        if !draft.isValid {
            return "Pick at least one day."
        }
        switch draft.choice {
        case .never:
            return "Adds to today only."
        case .everyDay:
            return "Appears in every day's plan automatically."
        case .certainDays:
            return "Appears on matching days automatically. Changes apply from tomorrow."
        }
    }

    private func choiceButton(_ choice: ActivityRepeatChoice, title: String) -> some View {
        let isSelected = draft.choice == choice
        return Text(title)
            .font(TyfeTypography.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(isSelected ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
            .padding(.horizontal, TyfeSpacing.relatedGap)
            .frame(minHeight: 36)
            .frame(maxWidth: .infinity)
            .background(isSelected ? TyfeEditorialPalette.teal : TyfeEditorialPalette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
            .asButton(.press) {
                draft.choice = choice
            }
            .accessibilityIdentifier(accessibilityIdentifier(for: choice))
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var weekdayPicker: some View {
        HStack(spacing: TyfeSpacing.relatedGap) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isSelected = draft.weekdays.contains(weekday)
                Text(Self.weekdayLetters[weekday - 1])
                    .font(TyfeTypography.interfaceStrong)
                    .foregroundStyle(isSelected ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? TyfeEditorialPalette.teal : TyfeEditorialPalette.canvas)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
                    }
                    .asButton(.press) {
                        if isSelected {
                            draft.weekdays.remove(weekday)
                        } else {
                            draft.weekdays.insert(weekday)
                        }
                    }
                    .accessibilityIdentifier("activity-repeat-weekday-\(weekday)")
                    .accessibilityLabel(Self.weekdayFullNames[weekday - 1])
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orderedWeekdays: [Int] {
        let firstISO = ActivityRecurrenceModel.isoWeekday(
            fromCalendarWeekday: Calendar.current.firstWeekday
        )
        return (0..<7).map { ((firstISO - 1 + $0) % 7) + 1 }
    }

    private func accessibilityIdentifier(for choice: ActivityRepeatChoice) -> String {
        switch choice {
        case .never: return "activity-repeat-never"
        case .everyDay: return "activity-repeat-every-day"
        case .certainDays: return "activity-repeat-certain-days"
        }
    }
}

#Preview("Repeat picker") {
    ActivityRepeatPickerPreview()
        .padding(TyfeSpacing.screenInset)
        .background(TyfeEditorialPalette.canvas)
}

private struct ActivityRepeatPickerPreview: View {
    @State private var draft = ActivityRepeatDraft(
        recurrence: ActivityRecurrenceModel(kind: .weekly, weekdays: [1, 3, 5])
    )

    var body: some View {
        ActivityRepeatPickerView(draft: $draft)
    }
}
