import SwiftUI

struct TyfeTextFieldView: View {
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(TyfeTypography.interfaceStrong)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled()
        .padding(.horizontal, TyfeSpacing.control)
        .frame(minHeight: 52)
        .background(TyfeEditorialPalette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: TyfeRadius.control)
                .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
        }
    }
}

#Preview("Text field") {
    TyfeTextFieldView(placeholder: "Name your activity", text: .constant(""))
        .padding(TyfeSpacing.card)
        .background(TyfeEditorialPalette.paper)
}

#Preview("Secure field") {
    TyfeTextFieldView(placeholder: "Password", text: .constant(""), isSecure: true)
        .padding(TyfeSpacing.card)
        .background(TyfeEditorialPalette.paper)
}
