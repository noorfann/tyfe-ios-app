import SwiftUI
import SwiftfulUI

struct TodoRepeatPickerView: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var draft: TodoRepeatDraft

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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TyfeSpacing.relatedGap) { choices }.fixedSize(horizontal: true, vertical: false)
                    VStack(spacing: TyfeSpacing.relatedGap) { choices }
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

    @ViewBuilder private var choices: some View {
        choiceButton(.never, title: "Never")
        choiceButton(.everyDay, title: "Every day")
        choiceButton(.certainDays, title: "Certain days")
    }

    private var footnote: String {
        if !draft.isValid {
            return "Pick at least one day."
        }
        switch draft.choice {
        case .never:
            return "Stays open until completed. Does not repeat."
        case .everyDay:
            return "Completed tasks reopen the next day. Unfinished work carries forward."
        case .certainDays:
            return "Completed tasks reopen on the next matching day. Unfinished work carries forward."
        }
    }

    private func choiceButton(_ choice: TodoRepeatChoice, title: String) -> some View {
        let isSelected = draft.choice == choice
        return Text(title)
            .font(TyfeTypography.caption)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(isSelected ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
            .padding(.horizontal, TyfeSpacing.relatedGap)
            .frame(minHeight: 44)
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 68 : 44))], spacing: TyfeSpacing.relatedGap) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let isSelected = draft.weekdays.contains(weekday)
                Text(dynamicTypeSize.isAccessibilitySize ? RepeatSchedule.weekdayShortName(forISO: weekday) : Self.weekdayLetters[weekday - 1])
                    .font(TyfeTypography.interfaceStrong)
                    .foregroundStyle(isSelected ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
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
                    .accessibilityIdentifier("todo-repeat-weekday-\(weekday)")
                    .accessibilityLabel(Self.weekdayFullNames[weekday - 1])
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orderedWeekdays: [Int] {
        let firstISO = RepeatSchedule.isoWeekday(
            fromCalendarWeekday: Calendar.current.firstWeekday
        )
        return (0..<7).map { ((firstISO - 1 + $0) % 7) + 1 }
    }

    private func accessibilityIdentifier(for choice: TodoRepeatChoice) -> String {
        switch choice {
        case .never: return "todo-repeat-never"
        case .everyDay: return "todo-repeat-every-day"
        case .certainDays: return "todo-repeat-certain-days"
        }
    }
}

#Preview("Repeat picker") {
    TodoRepeatPickerPreview()
        .padding(TyfeSpacing.screenInset)
        .background(TyfeEditorialPalette.canvas)
}

#Preview("Variety") {
    ScrollView {
        VStack(spacing: TyfeSpacing.sectionGap) {
            TodoRepeatPickerPreview()
            TodoRepeatPickerPreview().frame(width: 288).environment(\.colorScheme, .dark)
            TodoRepeatPickerPreview().dynamicTypeSize(.accessibility3)
        }
        .padding(TyfeSpacing.screenInset)
    }
}

private struct TodoRepeatPickerPreview: View {
    @State private var draft = TodoRepeatDraft(
        recurrence: RepeatSchedule(kind: .weekly, weekdays: [1, 3, 5])
    )

    var body: some View {
        TodoRepeatPickerView(draft: $draft)
    }
}
