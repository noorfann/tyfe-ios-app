import SwiftUI

struct TyfeSummaryRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let value: String
    let completedCount: Int
    let totalCount: Int
    let accent: Color

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(totalCount), 0), 1)
    }

    var body: some View {
        HStack(spacing: TyfeSpacing.relatedGap) {
            ZStack {
                Circle().inset(by: TyfeStroke.emphasis / 2)
                    .stroke(TyfeEditorialPalette.disabledFill, lineWidth: TyfeStroke.emphasis)
                Circle().inset(by: TyfeStroke.emphasis / 2)
                    .trim(from: 0, to: progress)
                    .stroke(accent, lineWidth: TyfeStroke.emphasis)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                    label
                    count
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                label.layoutPriority(1)
                count.frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, TyfeSpacing.relatedGap)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }

    private var label: some View {
        Text(title).font(TyfeTypography.interfaceStrong)
            .foregroundStyle(TyfeEditorialPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var count: some View {
        Text(value).font(TyfeTypography.interface)
            .foregroundStyle(TyfeEditorialPalette.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Summaries · 390") {
    VStack {
        TyfeSummaryRowView(title: "Sessions", value: "0 of 5", completedCount: 0, totalCount: 5, accent: TyfeEditorialPalette.teal)
        TyfeSummaryRowView(title: "To Do", value: "2 done · 3 open", completedCount: 2, totalCount: 5, accent: TyfeEditorialPalette.saffron)
        TyfeSummaryRowView(title: "Habits today", value: "3 of 3 · 1 skipped", completedCount: 3, totalCount: 3, accent: TyfeEditorialPalette.teal)
    }
    .padding(TyfeSpacing.screenInset).frame(width: 390)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Summaries · 320 · Dark · Accessibility") {
    VStack {
        TyfeSummaryRowView(title: "To Do", value: "128 done · 246 open", completedCount: 128, totalCount: 374, accent: TyfeEditorialPalette.saffron)
        TyfeSummaryRowView(title: "Habits today", value: "0 of 0 · 3 skipped", completedCount: 0, totalCount: 0, accent: TyfeEditorialPalette.teal)
    }
    .padding(TyfeSpacing.screenInset).frame(width: 320)
    .background(TyfeEditorialPalette.canvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
