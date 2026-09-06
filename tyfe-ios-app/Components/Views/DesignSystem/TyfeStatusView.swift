import SwiftUI

enum TyfeStatusKind: Equatable, CaseIterable {
    case loading
    case empty
    case offline
    case error

    var title: String {
        switch self {
        case .loading: return "Loading your plan…"
        case .empty: return "Nothing planned yet"
        case .offline: return "You’re offline"
        case .error: return "Something went wrong"
        }
    }

    var message: String {
        switch self {
        case .loading: return "Getting your next useful step ready."
        case .empty: return "Create a Daily Plan when you’re ready to begin."
        case .offline: return "Your private progress stays on this device."
        case .error: return "Your local progress is safe. Try again when you’re ready."
        }
    }

    var symbolName: String {
        switch self {
        case .loading: return "hourglass"
        case .empty: return "square.dashed"
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct TyfeStatusView: View {
    let kind: TyfeStatusKind
    let onRetry: (() -> Void)?

    init(kind: TyfeStatusKind, onRetry: (() -> Void)? = nil) {
        self.kind = kind
        self.onRetry = onRetry
    }

    var body: some View {
        TyfeSurfaceView(role: kind == .error ? .warning : .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(spacing: TyfeSpacing.small) {
                    Image(systemName: kind.symbolName)
                        .font(.title3.weight(.bold))
                    Text(kind.title)
                        .font(TyfeTypography.interfaceStrong)
                }
                Text(kind.message)
                    .font(TyfeTypography.interface)
                if kind == .loading {
                    ProgressView()
                        .tint(TyfeEditorialPalette.ink)
                        .accessibilityLabel(Text("Loading"))
                } else if kind == .error, let onRetry {
                    TyfeActionButtonView(title: "Try again", systemImage: "arrow.clockwise", role: .secondary, onTap: onRetry)
                } else if kind == .empty, let onRetry {
                    TyfeActionButtonView(title: "Create plan", systemImage: "plus", onTap: onRetry)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(kind.title))
        .accessibilityValue(Text(kind.message))
    }
}

#Preview("Async states") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeStatusView(kind: .loading)
        TyfeStatusView(kind: .empty) {}
        TyfeStatusView(kind: .offline)
        TyfeStatusView(kind: .error) {}
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
