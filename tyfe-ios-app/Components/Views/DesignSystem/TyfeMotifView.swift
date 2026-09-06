import SwiftUI

enum TyfeMotifKind {
    case tile
    case badge
    case completion

    var symbolName: String {
        switch self {
        case .tile: return "square.grid.2x2.fill"
        case .badge: return "seal.fill"
        case .completion: return "checkmark"
        }
    }

    var label: String {
        switch self {
        case .tile: return "Decorative game tile"
        case .badge: return "Decorative progression badge"
        case .completion: return "Completion accent"
        }
    }

    var size: CGFloat {
        switch self {
        case .tile: return 64
        case .badge: return 72
        case .completion: return 88
        }
    }
}

struct TyfeMotifView: View {
    let kind: TyfeMotifKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Canvas { context, size in
                let inset: CGFloat = 4
                let rect = CGRect(
                    x: inset,
                    y: inset,
                    width: size.width - inset * 2,
                    height: size.height - inset * 2
                )
                let tile = Path(roundedRect: rect, cornerRadius: TyfeRadius.control)
                let fillColor: Color = switch kind {
                case .tile: TyfeEditorialPalette.teal
                case .badge: TyfeEditorialPalette.slateBlue
                case .completion: TyfeEditorialPalette.focus
                }
                context.fill(tile, with: .color(fillColor))
                context.stroke(
                    tile,
                    with: .color(TyfeEditorialPalette.ink),
                    style: StrokeStyle(lineWidth: TyfeStroke.standard)
                )
            }
            Image(systemName: kind.symbolName)
                .font(.title2.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
        }
        .frame(width: kind.size, height: kind.size)
        .rotationEffect(reduceMotion ? .zero : .degrees(2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.label))
    }
}

#Preview("Motifs") {
    HStack(spacing: TyfeSpacing.control) {
        TyfeMotifView(kind: .tile)
        TyfeMotifView(kind: .badge)
        TyfeMotifView(kind: .completion)
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
