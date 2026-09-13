//
//  AppView.swift
//  
//
//  
//
import SwiftUI
import SwiftfulUI

struct AppView<Content: View>: View {

    @State private var presenter: AppPresenter
    private let content: () -> Content

    init(
        presenter: AppPresenter,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _presenter = State(initialValue: presenter)
        self.content = content
    }

    var body: some View {
        ZStack {
            RootView(
                delegate: RootDelegate(
                    onApplicationDidAppear: nil,
                    onApplicationWillEnterForeground: { _ in
                        Task {
                            await presenter.checkUserStatus()
                        }
                    },
                    onApplicationDidBecomeActive: nil,
                    onApplicationWillResignActive: nil,
                    onApplicationDidEnterBackground: nil,
                    onApplicationWillTerminate: nil
                ),
                content: {
                    content()
                        .task {
                            await presenter.checkUserStatus()
                        }
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            await presenter.showATTPromptIfNeeded()
                        }
                        .onChange(of: presenter.auth?.uid) { _, newValue in
                            if newValue == nil || newValue?.isEmpty == true {
                                Task {
                                    await presenter.checkUserStatus()
                                }
                            }
                        }
                }
            )
            .onAppear {
                presenter.onViewAppear()
            }
            .onDisappear {
                presenter.onViewDisappear()
            }
        }
        .preferredColorScheme(presenter.colorScheme)
    }
}

#Preview("AppView - Tabbar") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return builder.appView()
}
#Preview("AppView - Onboarding") {
    let container = DevPreview.shared.container()
    container.register(UserManager.self, service: UserManager.mock())
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: nil)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return builder.appView()
}

extension CoreBuilder {
    
    func appView() -> some View {
        AppView(
            presenter: AppPresenter(
                interactor: interactor
            ),
            content: {
                switch interactor.startingModuleId {
                case Constants.tabbarModuleId:
                    let delegate = ModuleWrapperDelegate(moduleId: Constants.tabbarModuleId)
                    RouterView(id: delegate.moduleId, addNavigationStack: false, addModuleSupport: true) { router in
                        coreModuleEntryView(router: router, delegate: delegate)
                    }
                default:
                    let delegate = ModuleWrapperDelegate(moduleId: Constants.onboardingModuleId)
                    RouterView(id: delegate.moduleId, addNavigationStack: false, addModuleSupport: true) { router in
                        onboardingModuleEntryView(router: router, delegate: delegate)
                    }
                }
            }
        )
    }

    func onboardingModuleEntryView(router: AnyRouter, delegate: ModuleWrapperDelegate) -> some View {
        moduleWrapperView(router: router, delegate: delegate) {
            onboardingFlow()
        }
    }

    func coreModuleEntryView(router: AnyRouter, delegate: ModuleWrapperDelegate) -> some View {
        moduleWrapperView(router: router, delegate: delegate) {
            coreModuleTabBarView(router: router)
        }
    }

    private func coreModuleTabBarView(router: AnyRouter) -> some View {
        let tabs: [TabBarTab] = [
            TabBarTab(title: "Today", systemImage: "sun.max.fill", destination: { router in
                todayView(router: router, delegate: TodayDelegate())
            }),
            TabBarTab(title: "Rewards", systemImage: "gift.fill", destination: { router in
                rewardsView(router: router, delegate: RewardsDelegate())
            }),
            TabBarTab(title: "Circles", systemImage: "person.3.fill", destination: { router in
                circlesView(router: router, delegate: CirclesDelegate())
            }),
            TabBarTab(title: "Settings", systemImage: "gearshape.fill", destination: { router in
                settingsView(router: router)
            })
        ]
        
        return tabBarView(
            router: router,
            delegate: TabBarDelegate(
                tabs: tabs,
                startingTabId: tabs.first?.id
            )
        )
    }
}

extension CoreRouter {
    
    func switchToCoreModule() {
        let delegate = ModuleWrapperDelegate(moduleId: Constants.tabbarModuleId)
        router.showModule(.top(animation: .snappy), id: delegate.moduleId, onDismiss: nil) { router in
            self.builder.coreModuleEntryView(router: router, delegate: delegate)
        }
    }
    
}

extension CoreRouter {
    
    func switchToOnboardingModule() {
        let delegate = ModuleWrapperDelegate(moduleId: Constants.onboardingModuleId)
        router.showModule(.bottom(animation: .snappy), id: delegate.moduleId, onDismiss: nil) { router in
            self.builder.onboardingModuleEntryView(router: router, delegate: delegate)
        }
    }
}
