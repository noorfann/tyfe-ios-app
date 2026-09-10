import SwiftUI
import SwiftfulUI

struct RewardsCreateRewardSheet: View {

    @Environment(\.dismiss) private var dismiss

    let onSave: (_ name: String, _ tier: RewardDurationTier) -> Void
    let onCancel: () -> Void

    @State private var rewardName = ""
    @State private var selectedTier: RewardDurationTier = .fifteenMinutes

    private var canSave: Bool {
        !rewardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    nameForm
                    tierPicker
                    TyfeActionButtonView(
                        title: "Save Reward",
                        systemImage: "checkmark",
                        isEnabled: canSave,
                        onTap: save
                    )
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            Text("NEW REWARD")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) {
                    onCancel()
                    dismiss()
                }
                .accessibilityLabel("Close")
        }
    }

    private var nameForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("REWARD NAME")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TextField("Read for a while", text: $rewardName)
                    .font(TyfeTypography.interfaceStrong)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .padding(.horizontal, TyfeSpacing.control)
                    .frame(minHeight: 52)
                    .background(TyfeEditorialPalette.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeRadius.control)
                            .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
                    }
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
        dismiss()
    }
}

#Preview("New reward sheet") {
    RewardsCreateRewardSheet(onSave: { _, _ in }, onCancel: {})
}
