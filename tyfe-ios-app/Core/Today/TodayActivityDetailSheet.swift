import SwiftUI
import SwiftfulUI

struct TodayActivityDetailSheet: View {

    let activity: ActivityModel
    let initialSessionCount: Int
    let completedSessionCount: Int
    let onSave: (_ name: String, _ category: ActivityCategory?, _ sessionCount: Int) -> Void
    let onRemove: (() -> Void)?

    @State private var activityName: String
    @State private var selectedCategory: ActivityCategory?
    @State private var sessionCount: Int

    init(
        activity: ActivityModel,
        initialSessionCount: Int,
        completedSessionCount: Int,
        onSave: @escaping (_ name: String, _ category: ActivityCategory?, _ sessionCount: Int) -> Void,
        onRemove: (() -> Void)?
    ) {
        let minimumSessionCount = max(completedSessionCount, 1)
        self.activity = activity
        self.initialSessionCount = initialSessionCount
        self.completedSessionCount = completedSessionCount
        self.onSave = onSave
        self.onRemove = onRemove
        _activityName = State(initialValue: activity.name)
        _selectedCategory = State(initialValue: activity.category)
        _sessionCount = State(initialValue: max(initialSessionCount, minimumSessionCount))
    }

    private var minimumSessionCount: Int {
        max(completedSessionCount, 1)
    }

    private var canSave: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            activityForm
            durationPicker
            TyfeActionButtonView(
                title: "Save Changes",
                systemImage: "checkmark",
                isEnabled: canSave,
                onTap: save
            )

            if completedSessionCount == 0, let onRemove {
                TyfeActionButtonView(
                    title: "Remove from Today",
                    systemImage: "trash",
                    role: .destructive,
                    onTap: onRemove
                )
            }
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

                Picker("Category", selection: $selectedCategory) {
                    Text("Uncategorized")
                        .tag(nil as ActivityCategory?)
                    ForEach(ActivityCategory.allCases, id: \.self) { category in
                        Text(category.displayName)
                            .tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)
                .tint(TyfeEditorialPalette.ink)
                .frame(minHeight: 44, alignment: .leading)
            }
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
                        isEnabled: sessionCount > minimumSessionCount
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
                        Text("\(completedSessionCount) completed")
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
        onSave(activityName, selectedCategory, sessionCount)
    }
}

#Preview("Activity detail — editable") {
    TodayActivityDetailSheet(
        activity: .mock,
        initialSessionCount: 3,
        completedSessionCount: 0,
        onSave: { _, _, _ in },
        onRemove: { }
    )
    .padding()
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Activity detail — partially completed") {
    TodayActivityDetailSheet(
        activity: .mock,
        initialSessionCount: 3,
        completedSessionCount: 1,
        onSave: { _, _, _ in },
        onRemove: nil
    )
    .padding()
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Activity detail — completed") {
    TodayActivityDetailSheet(
        activity: .mock,
        initialSessionCount: 2,
        completedSessionCount: 2,
        onSave: { _, _, _ in },
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
            completedSessionCount: 1,
            onSave: { _, _, _ in },
            onRemove: nil
        )
        .padding()
    }
    .background(TyfeEditorialPalette.canvas)
    .environment(\.dynamicTypeSize, .accessibility3)
}
