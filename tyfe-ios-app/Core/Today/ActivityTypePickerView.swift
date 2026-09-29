import SwiftUI
import SwiftfulUI

struct ActivityTypePickerView: View {

    @Binding var selection: ActivityType
    var isOptionEnabled: (ActivityType) -> Bool

    init(
        selection: Binding<ActivityType>,
        isOptionEnabled: @escaping (ActivityType) -> Bool = { _ in true }
    ) {
        _selection = selection
        self.isOptionEnabled = isOptionEnabled
    }

    var body: some View {
        HStack(spacing: TyfeSpacing.small) {
            typeOption(.session)
            typeOption(.checklist)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity type")
    }

    private func typeOption(_ type: ActivityType) -> some View {
        let isSelected = selection == type
        let isEnabled = isOptionEnabled(type)
        return Text(type.displayName)
            .font(TyfeTypography.interfaceStrong)
            .foregroundStyle(optionForeground(isSelected: isSelected, isEnabled: isEnabled))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? TyfeEditorialPalette.teal : TyfeEditorialPalette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
            .contentShape(Rectangle())
            .asButton(.press) {
                guard isEnabled else { return }
                selection = type
            }
            .disabled(!isEnabled)
            .accessibilityLabel("\(type.displayName) activity type")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint(isEnabled ? "" : "Unavailable while this activity has recorded progress today")
    }

    private func optionForeground(isSelected: Bool, isEnabled: Bool) -> Color {
        guard isEnabled else { return TyfeEditorialPalette.disabledInk }
        return isSelected ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink
    }
}
