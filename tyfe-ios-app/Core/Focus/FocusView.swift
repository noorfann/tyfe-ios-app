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
    @Environment(\.selectTab) private var selectTab
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
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
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
            VStack(spacing: TyfeSpacing.card) {
                focusTopBar

                if presenter.session.state == .completed || presenter.session.state == .abandoned {
                    outcome
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    focusTimer
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.top, TyfeSpacing.small)
            .padding(.bottom, TyfeSpacing.section)
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : TyfeMotion.normalAnimation, value: presenter.session.state)
    }

    private var focusTopBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.headline)
                .foregroundStyle(TyfeEditorialPalette.focus)
                .accessibilityHidden(true)

            Text("FOCUS CHAMBER")
                .font(TyfeTypography.eyebrow)
                .tracking(1.4)
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.onAccent)
                .frame(width: 44, height: 44)
                .background(TyfeEditorialPalette.focus)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: TyfeRadius.control, style: .continuous)
                        .stroke(
                            TyfeEditorialPalette.onAccent,
                            lineWidth: TyfeStroke.standard
                        )
                }
                .asButton(.press) {
                    presenter.onMinimizePressed()
                }
                .accessibilityLabel("Minimize Focus")
                .accessibilityHint("Returns to the app while preserving the current session")
        }
        .frame(minHeight: 44)
    }

    private var timerProgress: Double {
        if presenter.isPaused {
            guard presenter.session.pauseAllowanceSeconds > 0 else { return 0 }
            return Double(presenter.remainingPauseSeconds) / Double(presenter.session.pauseAllowanceSeconds)
        }

        guard presenter.session.durationSeconds > 0 else { return 0 }
        return Double(presenter.remainingFocusSeconds) / Double(presenter.session.durationSeconds)
    }

    private var focusTimer: some View {
        TyfeFocusTimerView(
            session: presenter.session,
            activityTitle: delegate.activityTitle,
            timeText: presenter.timerText,
            progress: timerProgress,
            supportingText: presenter.allowanceText,
            statusDescription: presenter.statusDescription,
            onBegin: presenter.onPrimaryActionPressed,
            onPause: presenter.onPrimaryActionPressed,
            onResume: presenter.onPrimaryActionPressed,
            onAbandon: presenter.onAbandonPressed
        )
#if MOCK
        .overlay(alignment: .bottomTrailing) {
            Text("Mark complete")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.58))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .asButton(.press) {
                    presenter.onMarkCompletePressed()
                }
                .accessibilityLabel("Mark complete")
                .padding(TyfeSpacing.small)
        }
#endif
    }

    private var outcome: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(spacing: TyfeSpacing.card) {
                Image(systemName: presenter.session.state.symbolName)
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(outcomeAccent)
                    .frame(width: 76, height: 76)
                    .background(outcomeAccent.opacity(0.14))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(spacing: TyfeSpacing.small) {
                    Text(presenter.session.state == .completed ? "Session complete" : "Session ended")
                        .font(TyfeTypography.display)
                        .multilineTextAlignment(.center)

                    Text(outcomeMessage)
                        .font(TyfeTypography.interface)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }

                VStack(spacing: TyfeSpacing.small) {
                    if presenter.session.state == .completed {
                        TyfeActionButtonView(
                            title: "Claim Reward",
                            systemImage: "gift.fill",
                            onTap: {
                                presenter.onClaimRewardPressed {
                                    selectTab("Rewards")
                                }
                            }
                        )

                        TyfeActionButtonView(
                            title: "Start another",
                            systemImage: "arrow.clockwise",
                            role: .secondary,
                            onTap: presenter.onStartAnotherPressed
                        )
                    }

                    Text("Back to Today")
                        .font(TyfeTypography.interfaceStrong)
                        .foregroundStyle(TyfeEditorialPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .asButton(.press) {
                            presenter.onBackToTodayPressed()
                        }
                        .accessibilityLabel("Back to Today")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presenter.session.state == .completed ? "Focus session complete" : "Focus session abandoned")
    }

    private var outcomeAccent: Color {
        presenter.session.state == .completed
            ? TyfeEditorialPalette.success
            : TyfeEditorialPalette.error
    }

    private var outcomeMessage: String {
        if let completion = presenter.completion, presenter.session.state == .completed {
            return "You earned +\(completion.rewardCreditsAwarded) Reward Credit."
        }
        if presenter.session.state == .completed {
            return "Your Reward Credit is ready."
        }
        return "No Reward Credit earned. You can begin again whenever you are ready."
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

#Preview("Focus - ready") {
    focusPreview(session: .readyMock)
}

#Preview("Focus - running dark") {
    focusPreview(session: .runningMock)
        .preferredColorScheme(.dark)
}

#Preview("Focus - paused") {
    focusPreview(session: .pausedMock)
}

#Preview("Focus - complete") {
    focusPreview(session: .completedMock)
}

#Preview("Focus - abandoned") {
    focusPreview(session: .abandonedMock)
}

#Preview("Focus - large type") {
    focusPreview(session: .runningMock)
        .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Focus - reduce motion") {
    focusPreview(session: .completedMock)
        .transaction { transaction in
            transaction.animation = nil
        }
}

@MainActor
private func focusPreview(session: FocusSessionModel) -> some View {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FocusDelegate(activity: .mock, session: session)

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
