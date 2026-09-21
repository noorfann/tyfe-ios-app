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
    @Environment(\.focusDaypartPreviewOverride) private var previewDaypart
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
            daypartBackground

            chamberContent(daypart: displayedDaypart)
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
        .interactiveDismissDisabled(presenter.session.state == .running)
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

    private var displayedDaypart: FocusDaypart {
        previewDaypart ?? presenter.daypart
    }

    private var daypartBackground: some View {
        ZStack {
            ForEach(FocusDaypart.allCases, id: \.self) { daypart in
                if daypart == displayedDaypart {
                    FocusDaypartBackground(daypart: daypart)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : chamberAnimation, value: displayedDaypart)
    }

    private func chamberContent(daypart: FocusDaypart) -> some View {
        ScrollView {
            VStack(spacing: TyfeSpacing.card) {
                focusTopBar(daypart: daypart)

                if presenter.isResting {
                    restTimer(daypart: daypart)
                        .transition(.opacity)
                } else if presenter.session.state == .completed || presenter.session.state == .abandoned {
                    outcome(daypart: daypart)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    focusTimer(daypart: daypart)
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
        .animation(reduceMotion ? nil : chamberAnimation, value: daypart)
    }

    private func focusTopBar(daypart: FocusDaypart) -> some View {
        HStack(spacing: 12) {
            Image(systemName: daypart.symbolName)
                .font(.headline)
                .foregroundStyle(daypart.symbolColor)
                .accessibilityHidden(true)

            Text(daypart.greeting)
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(daypart.visualStyle.backgroundForeground)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.black))
                .foregroundStyle(daypart.visualStyle.accentForeground)
                .frame(width: 44, height: 44)
                .background(daypart.visualStyle.accentFill)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: TyfeRadius.control, style: .continuous)
                        .stroke(
                            daypart.visualStyle.accentForeground,
                            lineWidth: TyfeStroke.standard
                        )
                }
                .asButton(.press) {
                    presenter.onMinimizePressed()
                }
                .disabled(presenter.session.state == .running)
                .accessibilityLabel("Minimize Focus")
                .accessibilityHint("Returns to the app while preserving the current session")
        }
        .frame(minHeight: 44)
    }

    private var timerProgress: Double {
        guard presenter.session.durationSeconds > 0 else { return 0 }
        return Double(presenter.remainingFocusSeconds) / Double(presenter.session.durationSeconds)
    }

    private func focusTimer(daypart: FocusDaypart) -> some View {
        TyfeFocusTimerView(
            session: presenter.session,
            daypart: daypart,
            activityTitle: delegate.activityTitle,
            timeText: presenter.timerText,
            progress: timerProgress,
            supportingText: presenter.allowanceText,
            statusDescription: presenter.statusDescription,
            onBegin: presenter.onPrimaryActionPressed,
            onAbandon: presenter.onAbandonPressed
        )
#if MOCK
        .overlay(alignment: .bottomTrailing) {
            Text("Mark complete")
                .font(TyfeTypography.caption)
                .foregroundStyle(daypart.visualStyle.secondaryForeground)
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

    private func restTimer(daypart: FocusDaypart) -> some View {
        let style = daypart.visualStyle

        return TyfeSurfaceView(
            role: .paper,
            fill: style.cardFill,
            foreground: style.primaryForeground,
            strokeColor: style.cardBorder
        ) {
            VStack(spacing: TyfeSpacing.card) {
                Image(systemName: "hourglass")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(style.accentForeground)
                    .frame(width: 76, height: 76)
                    .background(style.accentFill.opacity(0.14))
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                VStack(spacing: TyfeSpacing.small) {
                    Text("Take a 5-minute rest")
                        .font(TyfeTypography.display)
                        .multilineTextAlignment(.center)

                    Text("Let your mind reset before your next Focus Session.")
                        .font(TyfeTypography.interface)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(style.secondaryForeground)
                }

                Text(presenter.restTimerText)
                    .font(.system(size: 54, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(style.primaryForeground)
                    .accessibilityLabel("Rest timer")
                    .accessibilityValue(presenter.restTimerText)

                TyfeActionButtonView(
                    title: "Skip and start another",
                    systemImage: "arrow.clockwise",
                    fill: style.accentFill,
                    foreground: style.accentForeground,
                    borderColor: style.accentForeground,
                    onTap: presenter.onStartAnotherPressed
                )

                Text("Back to Today")
                    .font(TyfeTypography.interfaceStrong)
                    .foregroundStyle(style.primaryForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .asButton(.press) {
                        presenter.onBackToTodayPressed()
                    }
                    .accessibilityLabel("Back to Today")
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Five-minute Focus rest")
    }

    private func outcome(daypart: FocusDaypart) -> some View {
        let style = daypart.visualStyle

        return TyfeSurfaceView(
            role: .paper,
            fill: style.cardFill,
            foreground: style.primaryForeground,
            strokeColor: style.cardBorder
        ) {
            VStack(spacing: TyfeSpacing.card) {
                outcomeIcon
                outcomeCopy(style: style)
                outcomeActions(style: style)
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presenter.session.state == .completed ? "Focus session complete" : "Focus session abandoned")
    }

    private var outcomeIcon: some View {
        Image(systemName: presenter.session.state.symbolName)
            .font(.system(size: 38, weight: .black))
            .foregroundStyle(outcomeAccent)
            .frame(width: 76, height: 76)
            .background(outcomeAccent.opacity(0.14))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private func outcomeCopy(style: FocusDaypartVisualStyle) -> some View {
        VStack(spacing: TyfeSpacing.small) {
            Text(presenter.session.state == .completed ? "Session complete" : "Session ended")
                .font(TyfeTypography.display)
                .multilineTextAlignment(.center)

            Text(outcomeMessage)
                .font(TyfeTypography.interface)
                .multilineTextAlignment(.center)
                .foregroundStyle(style.secondaryForeground)
        }
    }

    private func outcomeActions(style: FocusDaypartVisualStyle) -> some View {
        VStack(spacing: TyfeSpacing.small) {
            if presenter.session.state == .completed {
                TyfeActionButtonView(
                    title: "Claim Reward",
                    systemImage: "gift.fill",
                    fill: style.accentFill,
                    foreground: style.accentForeground,
                    borderColor: style.accentForeground,
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
                    fill: style.accentFill.opacity(0.12),
                    foreground: style.primaryForeground,
                    borderColor: style.cardBorder,
                    onTap: presenter.onStartAnotherPressed
                )
            }

            Text("Back to Today")
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(style.primaryForeground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .asButton(.press) {
                    presenter.onBackToTodayPressed()
                }
                .accessibilityLabel("Back to Today")
        }
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

#Preview("Focus - running") {
    focusPreview(session: .runningMock)
}

#Preview("Focus - rest") {
    focusPreview(session: .restingMock)
}

#Preview("Focus - complete morning") {
    focusPreview(session: .completedMock)
        .environment(\.focusDaypartPreviewOverride, .morning)
}

#Preview("Focus - abandoned afternoon") {
    focusPreview(session: .abandonedMock)
        .environment(\.focusDaypartPreviewOverride, .afternoon)
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

#Preview("Focus - morning") {
    focusPreview(session: .runningMock)
        .environment(\.focusDaypartPreviewOverride, .morning)
}

#Preview("Focus - midday") {
    focusPreview(session: .runningMock)
        .environment(\.focusDaypartPreviewOverride, .midday)
}

#Preview("Focus - afternoon") {
    focusPreview(session: .runningMock)
        .environment(\.focusDaypartPreviewOverride, .afternoon)
}

#Preview("Focus - night") {
    focusPreview(session: .runningMock)
        .environment(\.focusDaypartPreviewOverride, .night)
}

@MainActor
private func focusPreview(session: FocusSessionModel) -> some View {
    var snapshot = LocalAppSnapshot.mock
    snapshot.focusSessions = [session]

    let container = DevPreview.shared.container(snapshotOverride: snapshot)
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
        router.showScreen(.fullScreenCover) { router in
            builder.focusView(router: router, delegate: delegate)
        }
    }
}
