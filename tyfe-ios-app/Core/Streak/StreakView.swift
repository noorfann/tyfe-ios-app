import SwiftUI
import SwiftfulUI

struct StreakDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct StreakView: View {

    @State private var presenter: StreakPresenter
    @State private var showCelebration = false
    @State private var celebrationTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    let delegate: StreakDelegate

    init(presenter: StreakPresenter, delegate: StreakDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    private var data: CurrentStreakData {
        presenter.currentStreakData
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                TyfeStreakHeroView(
                    streakCount: presenter.currentStreak,
                    state: presenter.heroState
                )

                streakSummary

                TyfeStreakWeekTrailView(days: presenter.recentDays)

                StreakMonthCalendarView(
                    month: presenter.calendarMonth,
                    canViewPreviousMonth: presenter.canViewPreviousMonth,
                    canViewNextMonth: presenter.canViewNextMonth,
                    isViewingCurrentMonth: presenter.isViewingCurrentMonth,
                    isLoading: presenter.isHistoryLoading,
                    hasError: presenter.hasHistoryError,
                    onPreviousMonth: presenter.onPreviousMonthPressed,
                    onNextMonth: presenter.onNextMonthPressed,
                    onToday: presenter.onTodayPressed,
                    onRetry: { presenter.onRetryHistoryPressed() }
                )
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.vertical, TyfeSpacing.control)
        }
        .scrollIndicators(.hidden)
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .foregroundStyle(TyfeEditorialPalette.ink)
        .overlay {
            if showCelebration && !reduceMotion {
                FocusConfettiView()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.success, trigger: celebrationTrigger)
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("streak-detail-screen")
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
            startCelebrationIfNeeded()
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presenter.refreshHistory() }
        }
        .onChange(of: data) { _, _ in
            presenter.refreshHistory()
        }
    }

    private func startCelebrationIfNeeded() {
        guard presenter.isMilestone else { return }
        celebrationTrigger += 1
        showCelebration = true
    }

    @ViewBuilder
    private var streakSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: TyfeSpacing.small) {
                longestRunCard
                freezeBankCard
            }
        } else {
            HStack(alignment: .top, spacing: TyfeSpacing.small) {
                longestRunCard
                freezeBankCard
            }
        }
    }

    private var longestRunCard: some View {
        TyfeStreakStatsView(longestStreak: presenter.longestStreak)
    }

    private var freezeBankCard: some View {
        TyfeStreakFreezeBankView(
            progress: presenter.freezeProgress,
            guidance: presenter.freezeGuidance
        )
    }
}

struct StreakMonthCalendarView: View {
    let month: StreakCalendarMonth
    let canViewPreviousMonth: Bool
    let canViewNextMonth: Bool
    let isViewingCurrentMonth: Bool
    let isLoading: Bool
    let hasError: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onToday: () -> Void
    let onRetry: () -> Void

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("Activity")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.small) {
                    navigationButton(symbol: "chevron.left", label: "Previous month", enabled: canViewPreviousMonth, action: onPreviousMonth)
                    Text(month.title)
                        .font(TyfeTypography.displayCompact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("streak-calendar-month")
                    navigationButton(symbol: "chevron.right", label: "Next month", enabled: canViewNextMonth, action: onNextMonth)
                }
                if !isViewingCurrentMonth {
                    Text("Today")
                        .font(TyfeTypography.interfaceStrong)
                        .frame(minWidth: 44, minHeight: 44)
                        .asButton(.press, action: onToday)
                        .accessibilityLabel("Return to current month")
                        .accessibilityIdentifier("streak-current-month")
                }

                if isLoading {
                    ProgressView("Loading activity history")
                        .font(TyfeTypography.caption)
                }
                if hasError {
                    VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                        Text("Activity history is incomplete. Please try again.")
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                        Text("Retry")
                            .font(TyfeTypography.interfaceStrong)
                            .frame(minWidth: 44, minHeight: 44)
                            .asButton(.press, action: onRetry)
                            .accessibilityIdentifier("streak-history-retry")
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 7),
                    spacing: TyfeSpacing.small
                ) {
                    ForEach(month.days) { day in
                        StreakDayCell(day: day)
                    }
                }

                HStack(spacing: TyfeSpacing.control) {
                    legendItem(title: "Focus day", symbol: "flame.fill", color: TyfeEditorialPalette.warning)
                    legendItem(title: "Freeze", symbol: "snowflake", color: TyfeEditorialPalette.teal)
                }
            }
        }
        .accessibilityIdentifier("streak-activity-calendar")
    }

    private func navigationButton(symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.black))
            .foregroundStyle(enabled ? TyfeEditorialPalette.ink : TyfeEditorialPalette.disabledInk)
            .frame(width: 44, height: 44)
            .background(enabled ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .asButton(.press, action: action)
            .disabled(!enabled)
            .accessibilityLabel(label)
    }

    private func legendItem(title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: TyfeSpacing.unit) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(title)
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }
}

private struct StreakDayCell: View {
    let day: StreakCalendarDay

    var body: some View {
        VStack(spacing: TyfeSpacing.unit) {
            Text(day.date, format: .dateTime.day())
                .font(TyfeTypography.caption)
                .foregroundStyle(textColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor)
                .clipShape(Circle())

            HStack(spacing: TyfeSpacing.unit) {
                if day.hasFocus {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(TyfeEditorialPalette.warning)
                }
                if day.hasFreeze {
                    Image(systemName: "snowflake")
                        .foregroundStyle(TyfeEditorialPalette.teal)
                }
            }
            .font(.caption2.weight(.bold))
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        guard day.isSelectedMonth else { return .clear }
        if day.isToday {
            return TyfeEditorialPalette.saffron.opacity(0.28)
        }
        if day.hasFreeze {
            return TyfeEditorialPalette.teal.opacity(0.18)
        }
        if day.hasFocus {
            return TyfeEditorialPalette.success.opacity(0.18)
        }
        return .clear
    }

    private var textColor: Color {
        day.isSelectedMonth ? TyfeEditorialPalette.ink : TyfeEditorialPalette.muted.opacity(0.35)
    }

    private var accessibilityLabel: String {
        var values = [day.date.formatted(date: .complete, time: .omitted)]
        if day.hasFocus { values.append("Focus day") }
        if day.hasFreeze { values.append("Freeze used") }
        return values.joined(separator: ", ")
    }
}

#Preview("No Streak") {
    let container = DevPreview.shared.container()
    let streakData = CurrentStreakData(
        streakKey: Constants.streakKey,
        userId: "preview-user",
        currentStreak: 0,
        longestStreak: 0,
        totalEvents: 0,
        freezesAvailableCount: 0,
        eventsRequiredPerDay: 1,
        todayEventCount: 0
    )
    let streakManager = StreakManager(
        services: MockStreakServices(streak: streakData),
        configuration: StreakConfiguration.mockDefault()
    )
    container.register(StreakManager.self, key: Constants.streakKey, service: streakManager)
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.streakView(router: router, delegate: StreakDelegate())
    }
}

#Preview("Active Streak") {
    let container = DevPreview.shared.container()
    let streakData = CurrentStreakData.mockActive(currentStreak: 7, freezesAvailableCount: 2)
    let streakManager = StreakManager(
        services: MockStreakServices(streak: streakData),
        configuration: StreakConfiguration.mockDefault()
    )
    container.register(StreakManager.self, key: Constants.streakKey, service: streakManager)
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.streakView(router: router, delegate: StreakDelegate())
    }
}

#Preview("Accessible Streak") {
    let container = DevPreview.shared.container()
    let streakData = CurrentStreakData.mockActive(currentStreak: 7, freezesAvailableCount: 2)
    let streakManager = StreakManager(
        services: MockStreakServices(streak: streakData),
        configuration: StreakConfiguration.mockDefault()
    )
    container.register(StreakManager.self, key: Constants.streakKey, service: streakManager)
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.streakView(router: router, delegate: StreakDelegate())
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Calendar activity icons") {
    let calendar = Calendar.current
    let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    let focusDate = calendar.date(byAdding: .day, value: 4, to: monthStart) ?? monthStart
    let freezeDate = calendar.date(byAdding: .day, value: 5, to: monthStart) ?? monthStart
    let mixedDate = calendar.date(byAdding: .day, value: 6, to: monthStart) ?? monthStart

    let events = [
        StreakEvent.mock(dateCreated: focusDate),
        StreakEvent.mock(dateCreated: freezeDate, isFreeze: true),
        StreakEvent.mock(dateCreated: mixedDate),
        StreakEvent.mock(dateCreated: mixedDate, isFreeze: true)
    ]
    let month = StreakCalendarMonth(
        month: monthStart, today: Date(), calendar: calendar,
        eventsByDay: Dictionary(grouping: events) { calendar.startOfDay(for: $0.dateCreated) }
    )
    return StreakMonthCalendarView(
        month: month, canViewPreviousMonth: true, canViewNextMonth: false,
        isViewingCurrentMonth: true, isLoading: false, hasError: false,
        onPreviousMonth: { }, onNextMonth: { }, onToday: { }, onRetry: { }
    )
    .padding(TyfeSpacing.control)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Calendar — Variety") {
    let calendar = Calendar.current
    let today = Date()
    let historicalMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
    return ScrollView {
        VStack(spacing: TyfeSpacing.section) {
            ForEach(0..<3) { state in
                StreakMonthCalendarView(
                    month: StreakCalendarMonth(month: state == 0 ? historicalMonth : today, today: today, calendar: calendar, eventsByDay: [:]),
                    canViewPreviousMonth: state == 0, canViewNextMonth: state == 0,
                    isViewingCurrentMonth: state != 0, isLoading: state == 1, hasError: state == 2,
                    onPreviousMonth: { }, onNextMonth: { }, onToday: { }, onRetry: { }
                )
            }
        }
        .padding(TyfeSpacing.control)
    }
    .background(TyfeEditorialPalette.canvas)
}

extension CoreBuilder {

    func streakView(router: AnyRouter, delegate: StreakDelegate) -> some View {
        StreakView(
            presenter: StreakPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {

    func showStreakView(delegate: StreakDelegate) {
        router.showScreen(.push) { router in
            builder.streakView(router: router, delegate: delegate)
        }
    }
}
