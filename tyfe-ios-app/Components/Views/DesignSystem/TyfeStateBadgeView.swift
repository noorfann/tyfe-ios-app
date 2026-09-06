import SwiftUI

struct TyfeStateBadgeView: View {
    let state: FocusSessionState

    private var tone: TyfePillTone {
        switch state {
        case .ready: return .neutral
        case .running: return .success
        case .paused: return .warning
        case .completed: return .accent
        case .abandoned: return .error
        }
    }

    var body: some View {
        TyfePillView(label: state.displayName, systemImage: state.symbolName, tone: tone)
            .accessibilityLabel(Text("Focus status, \(state.displayName)"))
    }
}

#Preview("Focus state badges") {
    VStack(alignment: .leading, spacing: TyfeSpacing.small) {
        ForEach(FocusSessionState.allCases, id: \.self) { state in
            TyfeStateBadgeView(state: state)
        }
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
