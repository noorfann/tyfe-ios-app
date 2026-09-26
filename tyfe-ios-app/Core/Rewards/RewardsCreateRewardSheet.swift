import SwiftUI

struct RewardsCreateRewardSheet: View {

    let onSave: (_ name: String, _ tier: RewardDurationTier) -> Void

    @State private var rewardName = ""
    @State private var selectedTier: RewardDurationTier = .tenMinutes

    private var canSave: Bool {
        !rewardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            nameForm
            durationForm
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

    private var durationForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Text("DOWNTIME")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Picker("Downtime", selection: $selectedTier) {
                    ForEach(RewardDurationTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Downtime duration")

                Text("\(selectedTier.creditLabel) for \(selectedTier.durationMinutes) minutes")
                    .font(TyfeTypography.interfaceStrong)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("1 credit = 10 minutes")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func save() {
        guard canSave else { return }
        onSave(rewardName, selectedTier)
    }
}

#Preview("New reward sheet") {
    RewardsCreateRewardSheet(onSave: { _, _ in })
}
