import SwiftUI

struct StreakDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct StreakView: View {

    @State private var presenter: StreakPresenter
    @State private var showCelebration = false
    @State private var celebrationTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

                StreakMonthCalendarView(recentEvents: data.recentEvents ?? [])
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
    let recentEvents: [StreakEvent]

    private let calendar = Calendar.current
    private let currentMonth = Date()

    private var monthYearText: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var dates: [Date] = []
        var date = firstWeek.start
        while date < monthInterval.end {
            dates.append(date)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        return dates
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("Activity")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Text(monthYearText)
                    .font(TyfeTypography.displayCompact)

                HStack(spacing: 0) {
                    ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, day in
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
                    ForEach(daysInMonth, id: \.self) { date in
                        StreakDayCell(
                            date: date,
                            events: recentEvents.filter { calendar.isDate($0.dateCreated, inSameDayAs: date) },
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                        )
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
    let date: Date
    let events: [StreakEvent]
    let isCurrentMonth: Bool

    var body: some View {
        VStack(spacing: TyfeSpacing.unit) {
            Text(date, format: .dateTime.day())
                .font(TyfeTypography.caption)
                .foregroundStyle(textColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor)
                .clipShape(Circle())

            HStack(spacing: TyfeSpacing.unit) {
                if events.contains(where: { !$0.isFreeze }) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(TyfeEditorialPalette.warning)
                }
                if events.contains(where: { $0.isFreeze }) {
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
        guard isCurrentMonth else { return .clear }
        if Calendar.current.isDateInToday(date) {
            return TyfeEditorialPalette.saffron.opacity(0.28)
        }
        if events.contains(where: { $0.isFreeze }) {
            return TyfeEditorialPalette.teal.opacity(0.18)
        }
        if !events.isEmpty {
            return TyfeEditorialPalette.success.opacity(0.18)
        }
        return .clear
    }

    private var textColor: Color {
        isCurrentMonth ? TyfeEditorialPalette.ink : TyfeEditorialPalette.muted.opacity(0.35)
    }

    private var accessibilityLabel: String {
        var values = [date.formatted(date: .complete, time: .omitted)]
        if events.contains(where: { !$0.isFreeze }) { values.append("Focus day") }
        if events.contains(where: { $0.isFreeze }) { values.append("Freeze used") }
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

    return StreakMonthCalendarView(recentEvents: [
        StreakEvent.mock(dateCreated: focusDate),
        StreakEvent.mock(dateCreated: freezeDate, isFreeze: true),
        StreakEvent.mock(dateCreated: mixedDate),
        StreakEvent.mock(dateCreated: mixedDate, isFreeze: true)
    ])
    .padding(TyfeSpacing.control)
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
