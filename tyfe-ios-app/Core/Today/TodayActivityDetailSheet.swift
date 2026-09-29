import SwiftUI
import SwiftfulUI

struct TodayActivityDetailSheet: View {

    let activity: ActivityModel
    let initialSessionCount: Int
    let completedUnitCount: Int
    let checklistItems: [ChecklistItemModel]
    let tickedItemIds: Set<String>
    let canConvertToChecklist: Bool
    let canConvertToSession: Bool
    let projects: [ProjectModel]
    let onSave: (ActivitySheetDraft) -> Void
    let onRemove: (() -> Void)?

    @State private var activityName: String
    @State private var selectedType: ActivityType
    @State private var sessionCount: Int
    @State private var selectedProjectId: String?
    @State private var itemDrafts: [ChecklistItemDraft]
    @State private var repeatDraft: ActivityRepeatDraft

    init(
        activity: ActivityModel,
        initialSessionCount: Int,
        completedUnitCount: Int,
        checklistItems: [ChecklistItemModel],
        tickedItemIds: Set<String>,
        canConvertToChecklist: Bool,
        canConvertToSession: Bool,
        projects: [ProjectModel],
        onSave: @escaping (ActivitySheetDraft) -> Void,
        onRemove: (() -> Void)?
    ) {
        self.activity = activity
        self.initialSessionCount = initialSessionCount
        self.completedUnitCount = completedUnitCount
        self.checklistItems = checklistItems
        self.tickedItemIds = tickedItemIds
        self.canConvertToChecklist = canConvertToChecklist
        self.canConvertToSession = canConvertToSession
        self.projects = projects
        self.onSave = onSave
        self.onRemove = onRemove
        _activityName = State(initialValue: activity.name)
        _selectedType = State(initialValue: activity.type)
        _sessionCount = State(initialValue: max(initialSessionCount, completedUnitCount))
        _selectedProjectId = State(initialValue: activity.projectId)
        _itemDrafts = State(
            initialValue: checklistItems.map {
                ChecklistItemDraft(itemId: $0.itemId, title: $0.title, creditValue: $0.creditValue)
            }
        )
        _repeatDraft = State(initialValue: ActivityRepeatDraft(recurrence: activity.recurrence))
    }

    private var canSave: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && repeatDraft.isValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            activityForm
            if selectedType == .checklist {
                ChecklistItemsEditorView(items: $itemDrafts, lockedItemIds: tickedItemIds)
            } else {
                durationPicker
            }
            ActivityRepeatPickerView(draft: $repeatDraft)
            TyfeActionButtonView(
                title: "Save Changes",
                systemImage: "checkmark",
                isEnabled: canSave,
                onTap: save
            )

            if completedUnitCount == 0, let onRemove {
                TyfeActionButtonView(
                    title: "Remove from Today",
                    systemImage: "trash",
                    role: .destructive,
                    onTap: onRemove
                )
            }
        }
        .onChange(of: selectedType) { _, newType in
            guard newType == .session else { return }
            sessionCount = max(initialSessionCount, completedUnitCount, 1)
        }
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            Text("SPACE")
                .font(TyfeTypography.eyebrow)
                .tracking(1.1)
                .foregroundStyle(TyfeEditorialPalette.muted)

            Picker("Space", selection: $selectedProjectId) {
                Text("Other")
                    .tag(nil as String?)
                ForEach(projects) { project in
                    Text(project.name)
                        .tag(Optional(project.projectId))
                }
            }
            .pickerStyle(.menu)
            .tint(TyfeEditorialPalette.ink)
            .frame(minHeight: 44, alignment: .leading)
            .accessibilityLabel("Space")
            .accessibilityIdentifier("activity-space-picker")
        }
    }

    private var activityForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("ACTIVITY")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeTextFieldView(placeholder: "Name your activity", text: $activityName)
                ActivityTypePickerView(
                    selection: $selectedType,
                    isOptionEnabled: isTypeOptionEnabled
                )
                projectPicker
            }
        }
    }

    private func isTypeOptionEnabled(_ type: ActivityType) -> Bool {
        guard type != activity.type else { return true }
        switch type {
        case .session: return canConvertToSession
        case .checklist: return canConvertToChecklist
        }
    }

    private var durationPicker: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("PLANNED DURATION")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.control) {
                    counterButton(
                        systemImage: "minus",
                        label: "Fewer sessions",
                        isEnabled: sessionCount > max(completedUnitCount, 1)
                    ) {
                        sessionCount -= 1
                    }

                    VStack(spacing: TyfeSpacing.unit) {
                        Text("\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")")
                            .font(TyfeTypography.displayCompact)
                            .contentTransition(.numericText())
                        Text("\(sessionCount * FocusSessionModel.durationMinutes) minutes planned")
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                        Text("\(completedUnitCount) completed")
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                    .frame(maxWidth: .infinity)

                    counterButton(
                        systemImage: "plus",
                        label: "More sessions",
                        isEnabled: true
                    ) {
                        sessionCount += 1
                    }
                }
            }
        }
    }

    private func counterButton(
        systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.black))
            .foregroundStyle(isEnabled ? TyfeEditorialPalette.ink : TyfeEditorialPalette.disabledInk)
            .frame(width: 48, height: 48)
            .background(isEnabled ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
            .asButton(.press) {
                guard isEnabled else { return }
                action()
            }
            .disabled(!isEnabled)
            .accessibilityLabel(label)
    }

    private func save() {
        onSave(
            ActivitySheetDraft(
                name: activityName,
                category: activity.category,
                type: selectedType,
                checklistItems: itemDrafts,
                sessionCount: max(sessionCount, completedUnitCount, 1),
                projectId: selectedProjectId,
                recurrence: repeatDraft.recurrence(
                    defaultSessionCount: max(sessionCount, completedUnitCount, 1)
                )
            )
        )
    }
}

#Preview("Activity detail — editable") {
    TodayActivityDetailSheet(
        activity: .mock,
        initialSessionCount: 3,
        completedUnitCount: 0,
        checklistItems: [],
        tickedItemIds: [],
        canConvertToChecklist: true,
        canConvertToSession: true,
        projects: ProjectModel.mocks,
        onSave: { _ in },
        onRemove: { }
    )
    .padding()
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Activity detail — checklist") {
    TodayActivityDetailSheet(
        activity: .checklistMock,
        initialSessionCount: 2,
        completedUnitCount: 1,
        checklistItems: [
            ChecklistItemModel(
                itemId: "checklist-item-1",
                activityId: ActivityModel.checklistMock.activityId,
                title: "Wipe counters",
                creditValue: .halfCredit,
                createdAt: Date()
            ),
            ChecklistItemModel(
                itemId: "checklist-item-2",
                activityId: ActivityModel.checklistMock.activityId,
                title: "Take out trash",
                creditValue: .oneCredit,
                createdAt: Date()
            )
        ],
        tickedItemIds: ["checklist-item-1"],
        canConvertToChecklist: true,
        canConvertToSession: false,
        projects: ProjectModel.mocks,
        onSave: { _ in },
        onRemove: nil
    )
    .padding()
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Activity detail — Large Dynamic Type") {
    ScrollView {
        TodayActivityDetailSheet(
            activity: .mock,
            initialSessionCount: 3,
            completedUnitCount: 1,
            checklistItems: [],
            tickedItemIds: [],
            canConvertToChecklist: false,
            canConvertToSession: true,
            projects: ProjectModel.mocks,
            onSave: { _ in },
            onRemove: nil
        )
        .padding()
    }
    .background(TyfeEditorialPalette.canvas)
    .environment(\.dynamicTypeSize, .accessibility3)
}
