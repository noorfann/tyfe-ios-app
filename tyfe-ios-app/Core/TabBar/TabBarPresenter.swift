import SwiftUI
import SwiftfulUI

struct TabBarTab: Identifiable {
    var id: String {
        title
    }

    let title: String
    let systemImage: String
    let content: AnyView

    @MainActor
    init<T: View>(
        title: String,
        systemImage: String,
        destination: @escaping (AnyRouter) -> T
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = RouterView { router in
            destination(router)
        }
        .any()
    }
    
    var eventParameters: [String: Any] {
        [
            "tab_title": title,
            "tab_id": id,
            "tab_icon": systemImage
        ]
    }

    static func == (lhs: TabBarTab, rhs: TabBarTab) -> Bool {
        lhs.id == rhs.id
    }
}

enum TabBarProgressStatusKind: Equatable {
    case reward
    case focusRunning
    case focusPaused
}

struct TabBarProgressStatus: Equatable {
    let kind: TabBarProgressStatusKind
    let remainingSeconds: Int

    var timeText: String {
        let safeSeconds = max(remainingSeconds, 0)
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }
}

@Observable
@MainActor
class TabBarPresenter {

    private let interactor: TabBarInteractor
    private let router: TabBarRouter

    var tabs: [TabBarTab]
    var selectedTab: String

    init(interactor: TabBarInteractor, router: TabBarRouter, delegate: TabBarDelegate) {
        self.interactor = interactor
        self.router = router
        self.tabs = delegate.tabs
        self.selectedTab = delegate.startingTabId ?? ""
    }

    private(set) var progressRemainingSeconds = 0
    private var progressTickerTask: Task<Void, Never>?

    var progressStatusKind: TabBarProgressStatusKind? {
        if let focusSession = interactor.activeFocusSession,
           focusSession.state == .running || focusSession.state == .paused {
            guard !interactor.isFocusScreenVisible else { return nil }
            return focusSession.state == .paused ? .focusPaused : .focusRunning
        }

        guard interactor.activeRewardClaim?.state == .active else { return nil }
        return .reward
    }

    var progressStatus: TabBarProgressStatus? {
        guard let progressStatusKind else { return nil }
        return TabBarProgressStatus(
            kind: progressStatusKind,
            remainingSeconds: progressRemainingSeconds
        )
    }
    
    func onViewAppear(delegate: TabBarDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        syncProgressTicker()
    }

    func onViewDisappear(delegate: TabBarDelegate) {
        stopProgressTicker()
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onTabSelected(tabId: String, isSameTabTapped: Bool, delegate: TabBarDelegate) {
        guard let tab = tabs.first(where: { $0.id == tabId }) else { return }

        // Track analytics
        if isSameTabTapped {
            interactor.trackEvent(event: Event.tabReselected(tab: tab, delegate: delegate))
        } else {
            interactor.trackEvent(event: Event.tabSelected(tab: tab, delegate: delegate))
        }

        // Update selection
        selectedTab = tabId
    }

    func tabSelectionAction(delegate: TabBarDelegate) -> TabSelectionAction {
        TabSelectionAction { [weak self] tabId in
            guard let self else { return }
            self.onTabSelected(
                tabId: tabId,
                isSameTabTapped: tabId == self.selectedTab,
                delegate: delegate
            )
        }
    }

    func onProgressStatusPressed(delegate: TabBarDelegate) {
        guard let progressStatusKind else { return }

        switch progressStatusKind {
        case .reward:
            guard let rewardsTab = tabs.first(where: { $0.title == "Rewards" }) else { return }
            interactor.trackEvent(event: Event.rewardStatusPressed(delegate: delegate))
            selectedTab = rewardsTab.id
        case .focusRunning, .focusPaused:
            guard let focusSession = interactor.activeFocusSession,
                  let activity = interactor.activity(forFocusSession: focusSession),
                  let todayTab = tabs.first(where: { $0.title == "Today" }) else { return }
            interactor.trackEvent(
                event: Event.focusStatusPressed(session: focusSession, delegate: delegate)
            )
            selectedTab = todayTab.id
            router.showFocusOverlay(
                delegate: FocusDelegate(activity: activity, session: focusSession),
                tabSelectionAction: tabSelectionAction(delegate: delegate)
            )
        }
    }

    func syncProgressTicker() {
        refreshProgressState()
        if progressStatusKind != nil {
            startProgressTicker()
        } else {
            stopProgressTicker()
        }
    }

    private func startProgressTicker() {
        guard progressTickerTask == nil else { return }
        progressTickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tickProgress()
            }
        }
    }

    private func stopProgressTicker() {
        progressTickerTask?.cancel()
        progressTickerTask = nil
    }

    private func tickProgress() {
        refreshProgressState()
        if progressStatusKind == nil {
            stopProgressTicker()
        }
    }

    private func refreshProgressState() {
        _ = try? interactor.refreshRewardClaim()

        if let focusSession = interactor.activeFocusSession,
           focusSession.state == .running || focusSession.state == .paused {
            if let refresh = try? interactor.refreshFocusSession(
                focusSessionId: focusSession.focusSessionId
            ) {
                switch refresh.session.state {
                case .running:
                    progressRemainingSeconds = refresh.remainingFocusSeconds
                    return
                case .paused:
                    progressRemainingSeconds = refresh.remainingPauseSeconds
                    return
                case .ready, .completed, .abandoned:
                    break
                }
            }
        }

        guard let claim = interactor.activeRewardClaim,
              claim.state == .active,
              let endsAt = claim.endsAt else {
            progressRemainingSeconds = 0
            return
        }
        progressRemainingSeconds = max(Int(ceil(endsAt.timeIntervalSinceNow)), 0)
    }
}

extension TabBarPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TabBarDelegate)
        case onDisappear(delegate: TabBarDelegate)
        case tabSelected(tab: TabBarTab, delegate: TabBarDelegate)
        case tabReselected(tab: TabBarTab, delegate: TabBarDelegate)
        case rewardStatusPressed(delegate: TabBarDelegate)
        case focusStatusPressed(session: FocusSessionModel, delegate: TabBarDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "TabBarView_Appear"
            case .onDisappear:              return "TabBarView_Disappear"
            case .tabSelected:              return "TabBar_TabSelected"
            case .tabReselected:            return "TabBar_TabReselected"
            case .rewardStatusPressed:      return "TabBar_RewardStatusPressed"
            case .focusStatusPressed:       return "TabBar_FocusStatusPressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .tabSelected(tab: let tab, delegate: let delegate), .tabReselected(tab: let tab, delegate: let delegate):
                var params = tab.eventParameters
                params.merge(delegate.eventParameters)
                return params
            case .rewardStatusPressed(delegate: let delegate):
                return delegate.eventParameters
            case .focusStatusPressed(session: let session, delegate: let delegate):
                var params = session.eventParameters
                params.merge(delegate.eventParameters)
                return params
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
