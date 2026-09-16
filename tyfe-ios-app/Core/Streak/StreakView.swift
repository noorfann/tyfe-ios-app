import SwiftUI
import SwiftfulUI

struct StreakDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct StreakView: View {

    @State private var presenter: StreakPresenter
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
                hero
                metrics
                freezeGuidance
                activitySummary
                StreakMonthCalendarView(recentEvents: data.recentEvents ?? [])
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.vertical, TyfeSpacing.control)
        }
        .scrollIndicators(.hidden)
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .foregroundStyle(TyfeEditorialPalette.ink)
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("streak-detail-screen")
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var hero: some View {
        TyfeSurfaceView(role: .warning) {
            VStack(spacing: TyfeSpacing.small) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 42, weight: .black))
                    .accessibilityHidden(true)

                Text(String(data.currentStreak ?? 0))
                    .font(.system(size: 64, weight: .black, design: .serif))
                    .monospacedDigit()

                Text("DAY STREAK")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.4)

                Text(streakMessage)
                    .font(TyfeTypography.interface)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak")
        .accessibilityValue("\(data.currentStreak ?? 0) days")
    }

    private var metrics: some View {
        HStack(spacing: TyfeSpacing.control) {
            TyfeMetricCardView(
                title: "Longest",
                value: String(data.longestStreak ?? 0),
                detail: "days",
                systemImage: "trophy.fill",
                accent: TyfeEditorialPalette.saffron
            )

            TyfeMetricCardView(
                title: "Freezes",
                value: String(data.freezesAvailableCount ?? 0),
                detail: "available",
                systemImage: "snowflake",
                accent: TyfeEditorialPalette.teal
            )
        }
    }

    private var freezeGuidance: some View {
        TyfeSurfaceView(role: .paper) {
            HStack(alignment: .top, spacing: TyfeSpacing.small) {
                Image(systemName: "snowflake")
                    .foregroundStyle(TyfeEditorialPalette.teal)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                    Text("STREAK FREEZES")
                        .font(TyfeTypography.eyebrow)
                        .tracking(1.1)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                    Text(presenter.freezeGuidance)
                        .font(TyfeTypography.interface)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("streak-freeze-guidance")
    }

    @ViewBuilder
    private var activitySummary: some View {
        if let dateLastEvent = data.dateLastEvent {
            TyfeSurfaceView(role: .paper) {
                HStack(spacing: TyfeSpacing.small) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TyfeEditorialPalette.success)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                        Text("LAST STREAK ACTIVITY")
                            .font(TyfeTypography.eyebrow)
                            .tracking(1.1)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                        Text(dateLastEvent.formatted(date: .abbreviated, time: .omitted))
                            .font(TyfeTypography.interfaceStrong)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var streakMessage: String {
        switch data.currentStreak ?? 0 {
        case 0: return "Complete a focus session to begin your streak."
        case 1: return "Your streak has started. Keep making room for focus."
        default: return "Keep showing up, one focused day at a time."
        }
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
                Text("ACTIVITY CALENDAR")
                    .font(TyfeTypography.eyebrow)
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
                    legendItem(title: "Focus day", color: TyfeEditorialPalette.success)
                    legendItem(title: "Freeze", color: TyfeEditorialPalette.teal)
                }
            }
        }
        .accessibilityIdentifier("streak-activity-calendar")
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: TyfeSpacing.unit) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
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

            HStack(spacing: 2) {
                if events.contains(where: { !$0.isFreeze }) {
                    Circle().fill(TyfeEditorialPalette.success)
                }
                if events.contains(where: { $0.isFreeze }) {
                    Circle().fill(TyfeEditorialPalette.teal)
                }
            }
            .frame(width: 10, height: 4)
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
