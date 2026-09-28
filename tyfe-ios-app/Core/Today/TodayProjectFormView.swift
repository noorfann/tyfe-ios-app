import SwiftUI
import SwiftfulUI

struct TodayProjectFormView: View {

    let project: ProjectModel?
    let onSave: (_ name: String, _ colorToken: String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var projectName: String
    @State private var selectedColorToken: String
    @State private var validationMessage: String?

    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: TyfeSpacing.small), count: 3)

    init(
        project: ProjectModel?,
        onSave: @escaping (_ name: String, _ colorToken: String) -> Bool
    ) {
        self.project = project
        self.onSave = onSave
        _projectName = State(initialValue: project?.name ?? "")
        _selectedColorToken = State(
            initialValue: ProjectColorOption.normalizedToken(project?.resolvedColorToken)
        )
    }

    private var customColorSelection: Binding<Color> {
        Binding(
            get: { ProjectColorOption.color(for: selectedColorToken) },
            set: { selectedColorToken = ProjectColorOption.token(from: $0) }
        )
    }

    private var canSave: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            nameSection
            colorSection

            if let validationMessage {
                Text(validationMessage)
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.error)
            }

            TyfeActionButtonView(
                title: project == nil ? "Create Space" : "Save Changes",
                systemImage: "checkmark",
                isEnabled: canSave,
                onTap: save
            )
            .accessibilityIdentifier("project-form-save-button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameSection: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("SPACE NAME")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeTextFieldView(
                    placeholder: "Name your space",
                    text: Binding(
                        get: { projectName },
                        set: {
                            projectName = $0
                            validationMessage = nil
                        }
                    )
                )
                .accessibilityIdentifier("project-form-name-field")
            }
        }
    }

    private var colorSection: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("COLOR")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                LazyVGrid(columns: colorColumns, spacing: TyfeSpacing.small) {
                    ForEach(ProjectColorOption.allCases) { option in
                        colorButton(option)
                    }
                }

                ColorPicker("Custom color", selection: customColorSelection, supportsOpacity: false)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("project-custom-color-picker")
            }
        }
    }

    private func colorButton(_ option: ProjectColorOption) -> some View {
        let isSelected = selectedColorToken == option.rawValue

        return HStack(spacing: TyfeSpacing.small) {
            Circle()
                .fill(option.color)
                .frame(width: 24, height: 24)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(TyfeEditorialPalette.onAccent)
                    }
                }

            Text(option.title)
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, TyfeSpacing.small)
        .frame(minHeight: 44)
        .background(isSelected ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: TyfeRadius.control)
                .stroke(
                    isSelected ? TyfeEditorialPalette.ink : TyfeEditorialPalette.controlBorder,
                    lineWidth: isSelected ? TyfeStroke.standard : TyfeStroke.hairline
                )
        }
        .asButton(.press) {
            selectedColorToken = option.rawValue
        }
        .accessibilityLabel("\(option.title) space color")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("project-color-option-\(option.rawValue)")
    }

    private func save() {
        guard onSave(projectName, selectedColorToken) else {
            validationMessage = "Enter a unique Space name."
            return
        }
        dismiss()
    }
}
