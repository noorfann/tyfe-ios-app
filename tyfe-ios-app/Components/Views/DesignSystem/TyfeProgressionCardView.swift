import SwiftUI

struct TyfeProgressionCardView: View {
    let progression: ProgressionSnapshotModel
    let compact: Bool

    init(progression: ProgressionSnapshotModel, compact: Bool = false) {
        self.progression = progression
        self.compact = compact
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
                    Text("Progression")
                        .font(TyfeTypography.interfaceStrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TyfePillView(label: "Level \(progression.level)", systemImage: "sparkles", tone: .accent)
                }
                if progression.totalXP == 0 {
                    Text("Complete a Focus Session to start your Progression.")
                        .font(TyfeTypography.interface)
                } else {
                    Text("\(progression.totalXP) XP total")
                        .font(TyfeTypography.interface)
                    TyfeProgressBarView(
                        label: "Level \(progression.level)",
                        current: progression.currentLevelXP,
                        total: 100,
                        accent: TyfeEditorialPalette.focus
                    )
                    if !compact, let nextMilestone = progression.nextMilestone {
                        HStack(spacing: TyfeSpacing.small) {
                            Image(systemName: "lock.fill")
                            Text("Next unlock · \(nextMilestone.requiredXP) XP")
                        }
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Progression"))
        .accessibilityValue(Text("Level \(progression.level), \(progression.currentLevelXP) of 100 XP"))
    }
}

#Preview("Progression states") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeProgressionCardView(progression: .noXPMock)
        TyfeProgressionCardView(progression: .mock)
        TyfeProgressionCardView(progression: .levelUpMock)
        TyfeProgressionCardView(progression: .cosmeticUnlockedMock)
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
