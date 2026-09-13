import SwiftUI
import SwiftfulUI

struct TyfeBottomSheet<Content: View>: View {
    let title: String
    let onClose: () -> Void
    private let content: Content

    init(
        title: String,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            Text(title)
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press, action: onClose)
                .accessibilityLabel("Close")
        }
    }
}

extension View {

    func tyfeBottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.fraction(0.8)],
        title: String,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            TyfeBottomSheet(
                title: title,
                onClose: onClose ?? { isPresented.wrappedValue = false }
            ) {
                content()
            }
            .presentationDetents(detents)
        }
    }
}

#Preview("Bottom sheet") {
    TyfeBottomSheet(
        title: "New Reward",
        onClose: {},
        content: {
            TyfeSurfaceView(role: .paper) {
                Text("Sheet content")
                    .font(TyfeTypography.interfaceStrong)
            }
            TyfeActionButtonView(title: "Save Reward", systemImage: "checkmark", onTap: {})
        }
    )
}

#Preview("Bottom sheet — Dark") {
    TyfeBottomSheet(
        title: "New Reward",
        onClose: {},
        content: {
            TyfeSurfaceView(role: .paper) {
                Text("Sheet content")
                    .font(TyfeTypography.interfaceStrong)
            }
        }
    )
    .preferredColorScheme(.dark)
}

#Preview("Bottom sheet — Large Dynamic Type") {
    TyfeBottomSheet(
        title: "New Reward",
        onClose: {},
        content: {
            TyfeSurfaceView(role: .paper) {
                Text("Sheet content")
                    .font(TyfeTypography.interfaceStrong)
            }
        }
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
