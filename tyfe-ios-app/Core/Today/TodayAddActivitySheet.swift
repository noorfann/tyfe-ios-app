import SwiftUI
import SwiftfulUI

struct TodayAddActivitySheet: View {

    let projects: [ProjectModel]
    let onSave: (ActivitySheetDraft) -> Void

    @State private var activityName: String
    @State private var sessionCount: Int
    @State private var selectedProjectId: String?

    init(
        initialSessionCount: Int,
        projects: [ProjectModel],
        initialProjectId: String?,
        onSave: @escaping (ActivitySheetDraft) -> Void
    ) {
        self.projects = projects
        self.onSave = onSave
        _activityName = State(initialValue: "")
        _sessionCount = State(initialValue: max(initialSessionCount, 1))
        _selectedProjectId = State(initialValue: initialProjectId)
    }

    private var canSave: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
            activityForm
            sessionCountPicker
            TyfeActionButtonView(
                title: "Add to Today",
                systemImage: "checkmark",
                isEnabled: canSave,
                onTap: save
            )
        }
    }

    private var projectPicker: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
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
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                Text("ACTIVITY")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeTextFieldView(placeholder: "Name your activity", text: $activityName)
                    .accessibilityIdentifier("activity-name-field")

                Text("Session").font(TyfeTypography.interfaceStrong)
                projectPicker
            }
        }
    }

    private var sessionCountPicker: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                Text("HOW MANY SESSIONS?")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.itemGap) {
                    counterButton(
                        systemImage: "minus",
                        label: "Fewer sessions",
                        isEnabled: sessionCount > 1
                    ) {
                        sessionCount -= 1
                    }

                    VStack(spacing: TyfeSpacing.tightGap) {
                        Text("\(sessionCount)")
                            .font(TyfeTypography.displayCompact)
                        Text("\(sessionCount * FocusSessionModel.durationMinutes) minutes focus")
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
                category: nil,
                type: .session,
                checklistItems: [],
                sessionCount: sessionCount,
                projectId: selectedProjectId
            )
        )
    }
}
