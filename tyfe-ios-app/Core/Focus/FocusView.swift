import SwiftUI
import SwiftfulUI

struct FocusDelegate {
    let activity: ActivityModel
    let session: FocusSessionModel

    init(activity: ActivityModel, session: FocusSessionModel) {
        self.activity = activity
        self.session = session
    }

    init(activityTitle: String) {
        let activity = ActivityModel(
            activityId: "activity-focus-preview",
            name: activityTitle,
            category: .study,
            iconToken: "book.closed.fill",
            colorToken: "teal",
            createdAt: Date(timeIntervalSince1970: 1_756_944_000)
        )
        self.init(activity: activity, session: .readyMock)
    }

    var activityTitle: String {
        activity.name
    }

    var eventParameters: [String: Any]? {
        nil
    }
}

struct FocusView: View {

    @State var presenter: FocusPresenter
    let delegate: FocusDelegate

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showWarmSurface = true
    @State private var showCompletionConfetti = false

    private var chamberAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.18)
            : .easeInOut(duration: 0.55)
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.navy
                .ignoresSafeArea()

            chamberContent
                .opacity(showWarmSurface ? 0 : 1)
                .scaleEffect(showWarmSurface ? 0.985 : 1)
                .animation(chamberAnimation, value: showWarmSurface)

            if showWarmSurface {
                TyfeEditorialPalette.canvas
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            if showCompletionConfetti && !reduceMotion {
                FocusConfettiView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
            enterFocusChamber()
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                presenter.onSceneBecameActive()
            }
        }
        .onChange(of: presenter.session.state) { oldState, newState in
            if newState == .completed && oldState != .completed {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCompletionConfetti = true
                }
            } else if newState != .completed {
                showCompletionConfetti = false
            }
        }
    }

    private var chamberContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                focusTopBar
                activityHeader
                timer
                allowance
                if presenter.session.state == .completed || presenter.session.state == .abandoned {
                    outcome
                } else {
                    actions
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private var focusTopBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.headline)
                .foregroundStyle(TyfeEditorialPalette.focus)
                .accessibilityHidden(true)

            Text("FOCUS CHAMBER")
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("T")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.navy)
                .frame(width: 36, height: 36)
                .background(TyfeEditorialPalette.focus)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(TyfeEditorialPalette.onDark, lineWidth: 2)
                }
                .accessibilityLabel("Profile")
        }
    }

    private var activityHeader: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SELECTED ACTIVITY")
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.62))

                Text(delegate.activityTitle)
                    .font(.title2.weight(.black))
                    .foregroundStyle(TyfeEditorialPalette.onDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                Circle()
                    .fill(presenter.isPaused ? TyfeEditorialPalette.amber : TyfeEditorialPalette.focus)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Text(presenter.statusTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TyfeEditorialPalette.onDark)
            }
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(TyfeEditorialPalette.onDark.opacity(0.06))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(TyfeEditorialPalette.onDark.opacity(0.4), lineWidth: 1.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Session status")
            .accessibilityValue(presenter.statusTitle)
        }
    }

    private var timer: some View {
        ZStack {
            Circle()
                .stroke(TyfeEditorialPalette.onDark.opacity(0.12), lineWidth: 1)

            Circle()
                .stroke(
                    presenter.isPaused ? TyfeEditorialPalette.amber : TyfeEditorialPalette.focus,
                    lineWidth: 2
                )
                .padding(8)

            VStack(spacing: 10) {
                Text(presenter.timerText)
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(TyfeEditorialPalette.onDark)
                    .minimumScaleFactor(0.6)

                Text("25-minute Focus Session")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.62))
            }
        }
        .frame(width: 270, height: 270)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus Session timer")
        .accessibilityValue("\(presenter.timerText), \(presenter.statusTitle)")
    }

    private var allowance: some View {
        Text(presenter.allowanceText)
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.66))
            .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: presenter.primaryActionSystemImage)
                    .font(.subheadline.weight(.black))
                    .accessibilityHidden(true)

                Text(presenter.primaryActionTitle)
            }
            .font(.headline.weight(.black))
            .foregroundStyle(TyfeEditorialPalette.navy)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(TyfeEditorialPalette.focus)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .shadow(color: TyfeEditorialPalette.onDark.opacity(0.28), radius: 0, x: 3, y: 3)
            .asButton(.press) {
                presenter.onPrimaryActionPressed()
            }
            .accessibilityLabel(presenter.primaryActionTitle)

#if MOCK
            Text("Mark complete")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.66))
                .frame(minHeight: 44)
                .asButton(.press) {
                    presenter.onMarkCompletePressed()
                }
                .accessibilityLabel("Mark complete")
#endif

            Text("Abandon Session")
                .font(.subheadline.weight(.bold))
                .underline()
                .underline(true, color: TyfeEditorialPalette.onDark.opacity(0.55))
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.66))
                .frame(minHeight: 44)
                .asButton(.press) {
                    presenter.onAbandonPressed()
                }
        }
    }

    private var outcome: some View {
        TyfeSurfaceView(role: presenter.session.state == .completed ? .celebration : .warning) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Label(
                    presenter.session.state == .completed ? "Session complete" : "Session ended",
                    systemImage: presenter.session.state.symbolName
                )
                .font(TyfeTypography.displayCompact)

                if let completion = presenter.completion, presenter.session.state == .completed {
                    Text("You earned +\(completion.rewardCreditsAwarded) Reward Credit.")
                        .font(TyfeTypography.interfaceStrong)
                } else {
                    Text("No Reward Credit earned.")
                        .font(TyfeTypography.interfaceStrong)
                }

                if presenter.session.state == .completed {
                    Text("Claim a Reward")
                        .font(TyfeTypography.interfaceStrong)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(TyfeEditorialPalette.saffron)
                        .foregroundStyle(TyfeEditorialPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                        .asButton(.press) {
                            presenter.onClaimRewardPressed()
                        }
                }

                HStack(spacing: TyfeSpacing.small) {
                    if presenter.session.state == .completed {
                        Text("Start another")
                            .font(TyfeTypography.interfaceStrong)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(TyfeEditorialPalette.navy)
                            .foregroundStyle(TyfeEditorialPalette.onDark)
                            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                            .asButton(.press) {
                                presenter.onStartAnotherPressed()
                            }
                    }

                    Text("Back to Today")
                        .font(TyfeTypography.interfaceStrong)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(TyfeEditorialPalette.navy)
                        .foregroundStyle(TyfeEditorialPalette.onDark)
                        .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                        .asButton(.press) {
                            presenter.onBackToTodayPressed()
                        }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presenter.session.state == .completed ? "Focus session complete" : "Focus session abandoned")
    }

    private func enterFocusChamber() {
        if reduceMotion {
            showWarmSurface = false
            return
        }

        withAnimation(chamberAnimation) {
            showWarmSurface = false
        }
    }
}

#Preview("Running") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FocusDelegate(activity: .mock, session: .readyMock)

    return RouterView { router in
        builder.focusView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func focusView(router: AnyRouter, delegate: FocusDelegate) -> some View {
        FocusView(
            presenter: FocusPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                session: delegate.session
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {

    func showFocusView(delegate: FocusDelegate) {
        router.showScreen(.push) { router in
            builder.focusView(router: router, delegate: delegate)
        }
    }
}
