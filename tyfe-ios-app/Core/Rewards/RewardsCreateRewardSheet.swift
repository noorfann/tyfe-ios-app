import SwiftUI

struct RewardsCreateRewardSheet: View {

    let onSave: (_ name: String, _ tier: RewardDurationTier) -> Void

    @State private var rewardName = ""
    @State private var selectedTier: RewardDurationTier = .fifteenMinutes

    private var canSave: Bool {
        !rewardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            nameForm
            tierPicker
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

    private var tierPicker: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("DURATION TIER")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Picker("Duration tier", selection: $selectedTier) {
                    ForEach(RewardDurationTier.allCases, id: \.self) { tier in
                        Text("\(tier.durationMinutes) min · \(creditLabel(for: tier))")
                            .tag(tier)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }

    private func creditLabel(for tier: RewardDurationTier) -> String {
        tier.creditCost == 1 ? "1 Credit" : "\(tier.creditCost) Credits"
    }

    private func save() {
        guard canSave else { return }
        onSave(rewardName, selectedTier)
    }
}

#Preview("New reward sheet") {
    RewardsCreateRewardSheet(onSave: { _, _ in })
}
