import SwiftUI
import SwiftfulUI

struct TodayAddActivitySheet: View {

    @Environment(\.dismiss) private var dismiss

    let initialSessionCount: Int
    let onSave: (
        _ name: String,
        _ category: ActivityCategory,
        _ sessionCount: Int
    ) -> Void

    @State private var activityName: String
    @State private var selectedCategory: ActivityCategory
    @State private var sessionCount: Int

    init(
        initialSessionCount: Int,
        onSave: @escaping (
            _ name: String,
            _ category: ActivityCategory,
            _ sessionCount: Int
        ) -> Void
    ) {
        self.initialSessionCount = initialSessionCount
        self.onSave = onSave
        _activityName = State(initialValue: "")
        _selectedCategory = State(initialValue: .personal)
        _sessionCount = State(initialValue: max(initialSessionCount, 1))
    }

    private var canSave: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    activityForm
                    sessionCountPicker
                    TyfeActionButtonView(
                        title: "Add to Today",
                        systemImage: "checkmark",
                        isEnabled: canSave,
                        onTap: save
                    )
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            Text("ADD TO TODAY")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) {
                    dismiss()
                }
                .accessibilityLabel("Close")
        }
    }

    private var activityForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("ACTIVITY")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeTextFieldView(placeholder: "Study Swift", text: $activityName)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(ActivityCategory.allCases, id: \.self) { category in
                        Text(category.displayName)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(TyfeEditorialPalette.ink)
                .frame(minHeight: 44, alignment: .leading)
            }
        }
    }

    private var sessionCountPicker: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("HOW MANY SESSIONS?")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.control) {
                    counterButton(
                        systemImage: "minus",
                        label: "Fewer sessions",
                        isEnabled: sessionCount > 1
                    ) {
                        sessionCount -= 1
                    }

                    VStack(spacing: TyfeSpacing.unit) {
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
                    .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
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
            activityName,
            selectedCategory,
            sessionCount
        )
    }
}
