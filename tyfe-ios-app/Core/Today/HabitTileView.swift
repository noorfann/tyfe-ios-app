import SwiftUI
import SwiftfulUI

struct HabitTileView: View {
    private static let skippedMarkInset: CGFloat = 2
    let day: HabitGridDay
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(day.status == .completed ? accent : TyfeEditorialPalette.disabledFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if day.status == .skipped {
                    Rectangle().fill(TyfeEditorialPalette.muted).frame(height: 1).padding(Self.skippedMarkInset)
                } else if day.status == .missed {
                    RoundedRectangle(cornerRadius: 2).stroke(TyfeEditorialPalette.controlBorder, lineWidth: 1)
                }
                if day.isToday {
                    RoundedRectangle(cornerRadius: 2).stroke(TyfeEditorialPalette.ink, lineWidth: 1)
                }
            }
            .opacity(day.status == .unscheduled || day.status == .future ? 0.35 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(day.accessibilityLabel)
    }
}
