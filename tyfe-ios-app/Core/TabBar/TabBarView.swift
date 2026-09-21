import SwiftUI
import SwiftfulUI

struct TabSelectionAction: Sendable {
    private let action: @MainActor @Sendable (String) -> Void

    init(_ action: @escaping @MainActor @Sendable (String) -> Void) {
        self.action = action
    }

    @MainActor
    func callAsFunction(_ tabId: String) {
        action(tabId)
    }
}

private struct TabSelectionActionKey: EnvironmentKey {
    static let defaultValue = TabSelectionAction { _ in
        assertionFailure("TabSelectionAction must be injected before selecting a tab")
    }
}

extension EnvironmentValues {
    var selectTab: TabSelectionAction {
        get { self[TabSelectionActionKey.self] }
        set { self[TabSelectionActionKey.self] = newValue }
    }
}

struct TabBarDelegate {
    let tabs: [TabBarTab]
    let startingTabId: String?

    init(tabs: [TabBarTab], startingTabId: String? = nil) {
        self.tabs = tabs
        self.startingTabId = startingTabId
    }
    
    var eventParameters: [String: Any]? {
        var params: [String: Any] = [
            "tabs_count": tabs.count,
            "tabs_titles": tabs.map({ $0.title })
        ]
        if let startingTabId {
            params["tabs_starting_id"] = startingTabId
        }
        return params
    }
}

struct TabBarView: View {

    @State var presenter: TabBarPresenter
    let delegate: TabBarDelegate

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var statusBarAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: TyfeMotion.normalDuration)
    }

    private var tabSelectionAction: TabSelectionAction {
        presenter.tabSelectionAction(delegate: delegate)
    }

    // Custom binding to intercept tab selections
    private var selectionHandler: Binding<String> {
        Binding(
            get: {
                presenter.selectedTab
            },
            set: { newValue in
                let isSameTab = newValue == presenter.selectedTab
                presenter.onTabSelected(tabId: newValue, isSameTabTapped: isSameTab, delegate: delegate)
            }
        )
    }

    var body: some View {
        VStack(spacing: presenter.progressStatus == nil ? 0 : TyfeSpacing.small) {
            if let status = presenter.progressStatus {
                TyfeProgressStatusBarView(
                    title: status.kind.title,
                    timeText: status.timeText,
                    systemImage: status.kind.systemImage,
                    accent: status.kind.accent,
                    accessibilityHint: status.kind.accessibilityHint,
                    accessibilityIdentifier: status.kind.accessibilityIdentifier,
                    onTap: { presenter.onProgressStatusPressed(delegate: delegate) }
                )
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.small)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            TabView(selection: selectionHandler) {
                ForEach(delegate.tabs) { tab in
                    tab.content
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .tag(tab.id)
                }
            }
            .environment(
                \.selectTab,
                tabSelectionAction
            )
        }
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .animation(statusBarAnimation, value: presenter.progressStatusKind)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: presenter.progressStatusKind) { _, _ in
            presenter.syncProgressTicker()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                presenter.syncProgressTicker()
            }
        }
    }
}

#Preview("Real tabs") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ModuleWrapperDelegate(moduleId: Constants.tabbarModuleId)

    return RouterView { router in
        builder.coreModuleEntryView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func tabBarView(router: AnyRouter, delegate: TabBarDelegate) -> some View {
        TabBarView(
            presenter: TabBarPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            delegate: delegate
        )
    }

}

private extension TabBarProgressStatusKind {

    var title: String {
        switch self {
        case .reward: return "Reward in progress"
        case .focusRunning: return "Focus in progress"
        case .focusResting: return "Rest in progress"
        }
    }

    var systemImage: String {
        switch self {
        case .reward: return "clock.fill"
        case .focusRunning: return "timer"
        case .focusResting: return "hourglass"
        }
    }

    var accent: Color {
        switch self {
        case .reward: return TyfeEditorialPalette.saffron
        case .focusRunning, .focusResting: return TyfeEditorialPalette.focus
        }
    }

    var accessibilityHint: String {
        switch self {
        case .reward: return "Opens Rewards"
        case .focusRunning, .focusResting: return "Opens Focus"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .reward: return "reward-in-progress-status"
        case .focusRunning, .focusResting: return "focus-in-progress-status"
        }
    }
}

/*
 
 
 #Preview("Fake tabs") {
     TabBarView(
         tabs: [
             TabBarScreen(title: "Explore", systemImage: "eyes", screen: {
                 VStack(spacing: 20) {
                     Color.red
                 }
                 .any()
             }),
             TabBarScreen(title: "Chats", systemImage: "bubble.left.and.bubble.right.fill", screen: {
                 VStack(spacing: 20) {
                     Color.blue
                 }
                 .any()
             }),
             TabBarScreen(title: "Profile", systemImage: "person.fill", screen: {
                 VStack(spacing: 20) {
                     Color.green
                 }
                 .any()
             })
         ],
         onTabSelected: { tab, isSameTabTapped in
             print("🧪 Preview: Tab selected - \(tab.title), Same tab: \(isSameTabTapped)")
         }
     )
 }
 */
