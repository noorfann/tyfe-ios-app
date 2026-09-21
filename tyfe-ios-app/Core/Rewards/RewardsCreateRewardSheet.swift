import SwiftUI

struct RewardsCreateRewardSheet: View {

    let onSave: (_ name: String, _ tier: RewardDurationTier) -> Void

    @State private var rewardName = ""
    private var canSave: Bool {
        !rewardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            nameForm
            tierSummary
            TyfeActionButtonView(
                title: "Save Reward",
                systemImage: "checkmark",
                isEnabled: canSave,
                onTap: save
            )
        }
    }

    private var nameForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("REWARD NAME")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeTextFieldView(placeholder: "Read for a while", text: $rewardName)
            }
        }
    }

    private var tierSummary: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("REWARD RATE")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Text("1 Credit = 10 minutes")
                    .font(TyfeTypography.interfaceStrong)
            }
        }
    }

    private func save() {
        guard canSave else { return }
        onSave(rewardName, .tenMinutes)
    }
}

#Preview("New reward sheet") {
    RewardsCreateRewardSheet(onSave: { _, _ in })
}
