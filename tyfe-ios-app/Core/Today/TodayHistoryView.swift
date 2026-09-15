import SwiftUI
import SwiftfulUI

struct TodayDateNavigatorView: View {

    let title: String
    let dateLabel: String
    let canViewPreviousDay: Bool
    let canViewNextDay: Bool
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            HStack(spacing: TyfeSpacing.small) {
                navigationButton(
                    systemImage: "chevron.left",
                    label: "Previous day",
                    isEnabled: canViewPreviousDay,
                    action: onPreviousDay
                )

                VStack(spacing: TyfeSpacing.unit) {
                    Text(title)
                        .font(TyfeTypography.interfaceStrong)
                    Text(dateLabel)
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)

                navigationButton(
                    systemImage: "chevron.right",
                    label: "Next day",
                    isEnabled: canViewNextDay,
                    action: onNextDay
                )
            }
        }
    }

    private func navigationButton(
        systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.black))
            .foregroundStyle(isEnabled ? TyfeEditorialPalette.ink : TyfeEditorialPalette.disabledInk)
            .frame(width: 44, height: 44)
            .background(isEnabled ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
            }
            .asButton(.press) {
                guard isEnabled else { return }
                action()
            }
            .disabled(!isEnabled)
            .accessibilityLabel(label)
    }
}

struct TodayHistoricalEmptyView: View {

    let completedSessionCount: Int

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Image(systemName: completedSessionCount > 0 ? "timer" : "calendar.badge.minus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TyfeEditorialPalette.teal)
                    .accessibilityHidden(true)

                Text("No plan recorded")
                    .font(TyfeTypography.displayCompact)

                Text(message)
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        guard completedSessionCount > 0 else {
            return "No activity recorded for this day."
        }
        let noun = completedSessionCount == 1 ? "session was" : "sessions were"
        return "No plan was saved, but \(completedSessionCount) focus \(noun) completed."
    }
}

#Preview("Today — historical") {
    let container = historyPreviewContainer(recordedDaysAgo: 1, includesCompletion: true)
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        let presenter = TodayPresenter(
            interactor: builder.interactor,
            router: CoreRouter(router: router, builder: builder)
        )
        presenter.onPreviousDayPressed()
        return TodayView(presenter: presenter, delegate: TodayDelegate())
    }
}

#Preview("Today — historical empty") {
    let container = historyPreviewContainer(recordedDaysAgo: 2, includesCompletion: false)
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        let presenter = TodayPresenter(
            interactor: builder.interactor,
            router: CoreRouter(router: router, builder: builder)
        )
        presenter.onPreviousDayPressed()
        return TodayView(presenter: presenter, delegate: TodayDelegate())
    }
}

@MainActor
private func historyPreviewContainer(
    recordedDaysAgo: Int,
    includesCompletion: Bool
) -> DependencyContainer {
    let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
    let container = dependencies.container
    let activity = ActivityModel.mock
    let currentDay = LocalDay(containing: .now, calendar: .autoupdatingCurrent)
    let recordedDay = currentDay.adding(days: -recordedDaysAgo)
    let plan = DailyPlanModel(
        dailyPlanId: "daily-plan-history-preview",
        localDate: recordedDay.startDate,
        localDay: recordedDay,
        intendedSessionCount: 2,
        originalIntendedSessionCount: 2,
        activityIds: [activity.activityId],
        planItems: [
            DailyPlanItemModel(
                planItemId: "plan-item-history-preview",
                activityId: activity.activityId,
                plannedSessionCount: 2
            )
        ]
    )
    let sessions = includesCompletion ? [
        FocusSessionModel(
            focusSessionId: "focus-session-history-preview",
            activityId: activity.activityId,
            state: .completed,
            startedAt: recordedDay.startDate.addingTimeInterval(3_600),
            localDay: recordedDay,
            dailyPlanIdAtStart: plan.dailyPlanId,
            completedAt: recordedDay.startDate.addingTimeInterval(5_100)
        )
    ] : []
    let repository = MockLocalAppRepository(snapshot: LocalAppSnapshot(
        activities: [activity],
        dailyPlans: [plan],
        focusSessions: sessions,
        nextActivityNumber: 2,
        nextSessionNumber: 2
    ))
    container.register(TodayManager.self, service: TodayManager(repository: repository))
    return container
}
