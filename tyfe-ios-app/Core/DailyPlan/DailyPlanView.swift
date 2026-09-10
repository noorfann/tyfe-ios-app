import SwiftUI
import SwiftfulUI

struct DailyPlanDelegate {
    let activity: ActivityModel
    let existingPlan: DailyPlanModel?
    let onComplete: (() -> Void)?

    init(activity: ActivityModel, existingPlan: DailyPlanModel? = nil, onComplete: (() -> Void)? = nil) {
        self.activity = activity
        self.existingPlan = existingPlan
        self.onComplete = onComplete
    }

    var eventParameters: [String: Any]? { nil }
}

struct DailyPlanView: View {

    @State private var presenter: DailyPlanPresenter
    let delegate: DailyPlanDelegate

    init(presenter: DailyPlanPresenter, delegate: DailyPlanDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    intro
                    activitySummary
                    sessionCount
                    TyfeActionButtonView(
                        title: presenter.existingPlan == nil ? "Set today’s plan" : "Save plan changes",
                        systemImage: "checkmark",
                        onTap: presenter.acceptPlan
                    )
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) {
                    presenter.onBackPressed()
                }
                .accessibilityLabel("Back")

            Text("DAILY PLAN")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Make a little\nroom for focus.")
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)

            Text("Your plan is an intention, not a perfect schedule. You can adjust it later.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var activitySummary: some View {
        TyfeSurfaceView(role: .paper) {
            HStack(spacing: TyfeSpacing.control) {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .fill(TyfeEditorialPalette.teal)
                    .frame(width: 52, height: 52)
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeRadius.control)
                            .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.standard)
                        Image(systemName: presenter.activity.iconToken ?? "square.grid.2x2")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(TyfeEditorialPalette.ink)
                    }

                VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                    Text("FOCUS ACTIVITY")
                        .font(TyfeTypography.eyebrow)
                        .tracking(1.1)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                    Text(presenter.activity.name)
                        .font(TyfeTypography.interfaceStrong)
                        .foregroundStyle(TyfeEditorialPalette.ink)
                }
            }
        }
    }

    private var sessionCount: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("HOW MUCH FEELS RIGHT?")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.control) {
                    planCounterButton(
                        systemImage: "minus",
                        label: "Fewer sessions",
                        isEnabled: presenter.canDecrement,
                        action: presenter.decrementSessionCount
                    )

                    VStack(spacing: TyfeSpacing.unit) {
                        Text("\(presenter.intendedSessionCount)")
                            .font(TyfeTypography.displayCompact)
                            .foregroundStyle(TyfeEditorialPalette.ink)
                        Text(presenter.planSummary)
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                    .frame(maxWidth: .infinity)

                    planCounterButton(
                        systemImage: "plus",
                        label: "More sessions",
                        isEnabled: presenter.intendedSessionCount < 8,
                        action: presenter.incrementSessionCount
                    )
                }
            }
        }
    }

    private func planCounterButton(
        systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.black))
            .foregroundStyle(isEnabled ? TyfeEditorialPalette.ink : TyfeEditorialPalette.disabledInk)
            .frame(width: 48, height: 48)
            .background(isEnabled ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
            }
            .opacity(isEnabled ? 1 : 0.72)
            .asButton(.press) {
                action()
            }
            .disabled(!isEnabled)
            .accessibilityLabel(label)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.dailyPlanView(
            router: router,
            delegate: DailyPlanDelegate(activity: .mock)
        )
    }
}

extension CoreBuilder {
    func dailyPlanView(router: AnyRouter, delegate: DailyPlanDelegate) -> some View {
        DailyPlanView(
            presenter: DailyPlanPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showDailyPlanView(delegate: DailyPlanDelegate) {
        router.showScreen(.push) { router in
            builder.dailyPlanView(router: router, delegate: delegate)
        }
    }
}
