import SwiftUI

struct TyfeTextFieldView: View {
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        TextField(placeholder, text: $text)
            .font(TyfeTypography.interfaceStrong)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(.horizontal, TyfeSpacing.control)
            .frame(minHeight: 52)
            .background(TyfeEditorialPalette.canvas)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
            }
    }
}

#Preview("Text field") {
    TyfeTextFieldView(placeholder: "Study Swift", text: .constant(""))
        .padding(TyfeSpacing.card)
        .background(TyfeEditorialPalette.paper)
}
