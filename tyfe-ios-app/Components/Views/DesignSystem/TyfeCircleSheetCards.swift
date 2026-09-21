import SwiftUI

struct TyfeCircleNameSheetCardView: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    let actionTitle: String
    var autocapitalization: TextInputAutocapitalization = .sentences
    let onSave: () -> Void

    private var canSave: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    Text(label)
                        .font(TyfeTypography.eyebrow)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    TyfeTextFieldView(
                        placeholder: placeholder,
                        text: $value,
                        autocapitalization: autocapitalization
                    )
                }
            }

            TyfeActionButtonView(
                title: actionTitle,
                systemImage: "checkmark",
                isEnabled: canSave,
                onTap: onSave
            )
        }
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
