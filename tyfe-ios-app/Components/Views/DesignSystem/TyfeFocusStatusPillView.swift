import SwiftUI

struct TyfeFocusStatusPillView: View {
    let status: CircleFocusStatus

    var body: some View {
        TyfePillView(
            label: status.displayName,
            systemImage: status.symbolName,
            tone: status == .focusing ? .accent : .neutral
        )
        .accessibilityLabel(Text("Focus status, \(status.displayName)"))
    }
}

#Preview("Focus status pills") {
    HStack(spacing: TyfeSpacing.small) {
        ForEach(CircleFocusStatus.allCases, id: \.self) { status in
            TyfeFocusStatusPillView(status: status)
        }
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
