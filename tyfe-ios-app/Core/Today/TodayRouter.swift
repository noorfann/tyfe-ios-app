import SwiftUI

@MainActor
protocol TodayRouter: GlobalRouter {
    func showStarterActivityView(delegate: StarterActivityDelegate)
    func showDailyPlanView(delegate: DailyPlanDelegate)
    func showFocusView(delegate: FocusDelegate)
    func showStreakView(delegate: StreakDelegate)
    func showProjectManagementView(delegate: TodayProjectManagementDelegate)
    #if MOCK || DEV
    func showDevSettingsView()
    #endif
}

extension CoreRouter: TodayRouter { }

@MainActor
protocol TodayProjectManagementRouter: GlobalRouter {
    func confirmProjectDeletion(
        named projectName: String,
        onConfirm: @escaping @MainActor @Sendable () -> Void
    )
}

extension CoreRouter: TodayProjectManagementRouter {
    func confirmProjectDeletion(
        named projectName: String,
        onConfirm: @escaping @MainActor @Sendable () -> Void
    ) {
        showAlert(
            .alert,
            title: "Delete \(projectName)?",
            subtitle: "Its Activities move to Other. Plans and Focus history stay intact.",
            buttons: {
                AnyView(
                    Group {
                        Button("Delete Space", role: .destructive, action: onConfirm)
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }
}
