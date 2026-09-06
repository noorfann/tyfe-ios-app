import SwiftUI

enum TyfePillTone {
    case neutral
    case accent
    case success
    case warning
    case error
    case dark

    var fill: Color {
        switch self {
        case .neutral: return TyfeEditorialPalette.paper
        case .accent: return TyfeEditorialPalette.focus
        case .success: return TyfeEditorialPalette.success.opacity(0.16)
        case .warning: return TyfeEditorialPalette.saffron.opacity(0.32)
        case .error: return TyfeEditorialPalette.error.opacity(0.14)
        case .dark: return TyfeEditorialPalette.charcoal
        }
    }

    var foreground: Color {
        switch self {
        case .neutral, .accent, .warning: return TyfeEditorialPalette.ink
        case .success: return TyfeEditorialPalette.success
        case .error: return TyfeEditorialPalette.error
        case .dark: return TyfeEditorialPalette.onDark
        }
    }
}

struct TyfePillView: View {
    let label: String
    let systemImage: String?
    let tone: TyfePillTone

    init(
        label: String,
        systemImage: String? = nil,
        tone: TyfePillTone = .neutral
    ) {
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: TyfeSpacing.unit) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(label)
                .font(TyfeTypography.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, TyfeSpacing.small)
        .frame(minHeight: 28)
        .foregroundStyle(tone.foreground)
        .background(tone.fill)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
    }
}

#Preview("State pills") {
    HStack(spacing: TyfeSpacing.small) {
        TyfePillView(label: "Ready", systemImage: "play.fill")
        TyfePillView(label: "Focusing", systemImage: "timer", tone: .success)
        TyfePillView(label: "Paused", systemImage: "pause.fill", tone: .warning)
        TyfePillView(label: "Offline", systemImage: "wifi.slash", tone: .error)
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
