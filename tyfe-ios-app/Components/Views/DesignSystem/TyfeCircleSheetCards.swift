import SwiftUI

struct TyfeCircleNameSheetCardView: View {
    let title: String
    let placeholder: String
    @Binding var value: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: TyfeSpacing.control) {
            Text(title)
                .font(TyfeTypography.displayCompact)

            TyfeTextFieldView(placeholder: placeholder, text: $value)

            HStack(spacing: TyfeSpacing.small) {
                TyfeActionButtonView(title: "Cancel", role: .secondary, onTap: onCancel)
                TyfeActionButtonView(
                    title: "Save",
                    role: .primary,
                    isEnabled: !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onTap: onSave
                )
            }
        }
        .padding(TyfeSpacing.card)
    }
}

struct TyfeCircleErrorCardView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        TyfeSurfaceView(role: .warning) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                    .font(TyfeTypography.interfaceStrong)
                Text(message)
                    .font(TyfeTypography.interface)
                TyfeActionButtonView(title: "OK", role: .secondary, onTap: onDismiss)
            }
        }
    }
}
