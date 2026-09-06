import SwiftUI

struct TyfeProgressBarView: View {
    let label: String
    let current: Int
    let total: Int
    let accent: Color

    init(label: String, current: Int, total: Int, accent: Color = TyfeEditorialPalette.focus) {
        self.label = label
        self.current = current
        self.total = total
        self.accent = accent
    }

    private var safeTotal: Int {
        max(total, 1)
    }

    private var safeCurrent: Int {
        min(max(current, 0), safeTotal)
    }

    private var fraction: CGFloat {
        CGFloat(safeCurrent) / CGFloat(safeTotal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
                Text(label)
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                Text("\(safeCurrent) of \(safeTotal)")
                    .font(TyfeTypography.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(TyfeEditorialPalette.ink.opacity(0.12))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(8, proxy.size.width * fraction))
                        .overlay {
                            Capsule()
                                .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
                        }
                }
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text("\(safeCurrent) of \(safeTotal)"))
    }
}

#Preview("Progress — partial and complete") {
    VStack(alignment: .leading, spacing: TyfeSpacing.card) {
        TyfeProgressBarView(label: "Today's plan", current: 1, total: 3, accent: TyfeEditorialPalette.teal)
        TyfeProgressBarView(label: "Progression", current: 40, total: 100)
        TyfeProgressBarView(label: "Complete", current: 3, total: 3, accent: TyfeEditorialPalette.success)
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.paper)
}
