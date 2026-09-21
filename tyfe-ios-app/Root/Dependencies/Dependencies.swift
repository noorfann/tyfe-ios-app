//
//  Dependencies.swift
//  tyfe-ios-app
//
//  
//
import Foundation
import SwiftUI
import SwiftfulRouting
import SwiftfulDataManagers

@MainActor
struct Dependencies {
    let container: DependencyContainer

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    init(config: BuildConfiguration, snapshotOverride: LocalAppSnapshot? = nil) {
        let authManager: AuthManager
        let userManager: UserManager
        let abTestManager: ABTestManager
        let purchaseManager: PurchaseManager
        let appState: AppState
        let logManager: LogManager
        let pushManager: PushManager
        let liveActivityScheduler: FocusLiveActivityScheduling
        let hapticManager: HapticManager
        let soundEffectManager: SoundEffectManager
        let streakManager: StreakManager
        let progressManager: ProgressManager
        let repository: LocalAppRepository
        let todayManager: TodayManager
        let focusManager: FocusManager
        let rewardManager: RewardManager
        let supabaseService: SupabaseClientProviding
        let socialManager: SocialManager
        let emailAuthService: EmailAuthServicing
        
        switch config {
        case .mock(isSignedIn: let isSignedIn, addLogging: let addLogging):
            logManager = LogManager(services: addLogging ? [
                ConsoleService(printParameters: true, system: .stdout)
            ] : [])
            authManager = AuthManager(service: MockAuthService(user: isSignedIn ? .mock() : nil), logger: logManager)
            supabaseService = MockSupabaseClientService()
            userManager = UserManager(userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: isSignedIn ? UserModel.mock : nil),
                managerKey: "UserMan",
                enableLocalPersistence: false,
                logger: logManager
            ))
            
            // Note: configure AB tests for UI tests here
            //
            // let isInTest = ProcessInfo.processInfo.arguments.contains("SOMETEST")
            let abTestService = MockABTestService(
                boolTest: nil,
                enumTest: nil
            )
            abTestManager = ABTestManager(service: abTestService, logManager: logManager)
            purchaseManager = PurchaseManager(service: MockPurchaseService(activeEntitlements: [], availableProducts: AnyProduct.mocks), logger: logManager)
            appState = AppState(startingModuleId: isSignedIn ? Constants.tabbarModuleId : Constants.onboardingModuleId)
            hapticManager = HapticManager(logger: logManager)
            streakManager = StreakManager(services: MockStreakServices(), configuration: Dependencies.streakConfiguration, logger: logManager)
            progressManager = ProgressManager(services: MockProgressServices(), configuration: Dependencies.progressConfiguration, logger: logManager)
            socialManager = SocialManager(
                service: MockSocialService(currentUserId: UserAuthInfo.mock().uid),
                logManager: logManager
            )
            emailAuthService = MockEmailAuthService()
        case .dev, .prod:
            if case .dev = config {
                logManager = LogManager(services: [
                    ConsoleService(printParameters: true),
                    MixpanelService(token: Keys.mixpanelToken)
                ])
            } else {
                logManager = LogManager(services: [
                    MixpanelService(token: Keys.mixpanelToken)
                ])
            }
            #if !MOCK && canImport(Supabase)
            if let configuration = SupabaseConfiguration(
                urlString: Keys.supabaseURL,
                publishableKey: Keys.supabasePublishableKey
            ) {
                let liveService = LiveSupabaseClientService(configuration: configuration)
                supabaseService = liveService
                authManager = AuthManager(service: SupabaseAuthService(client: liveService.client), logger: logManager)
                socialManager = SocialManager(service: SupabaseSocialService(client: liveService.client), logManager: logManager, userDefaults: .standard)
                emailAuthService = SupabaseEmailAuthService(client: liveService.client)
            } else {
                supabaseService = MockSupabaseClientService()
                authManager = AuthManager(service: MockAuthService(user: nil), logger: logManager)
                socialManager = SocialManager(service: MockSocialService(), logManager: logManager, userDefaults: .standard)
                emailAuthService = MockEmailAuthService()
            }
            #else
            supabaseService = MockSupabaseClientService()
            authManager = AuthManager(service: MockAuthService(user: nil), logger: logManager)
            socialManager = SocialManager(service: MockSocialService(), logManager: logManager)
            emailAuthService = MockEmailAuthService()
            #endif
            userManager = UserManager(userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: nil),
                managerKey: "UserMan",
                enableLocalPersistence: true,
                logger: logManager
            ))
            abTestManager = ABTestManager(service: LocalABTestService(), logManager: logManager)
            purchaseManager = PurchaseManager(
                service: RevenueCatPurchaseService(apiKey: Keys.revenueCatAPIKey),
                logger: logManager
            )
            hapticManager = HapticManager(logger: logManager)
            appState = AppState()
            streakManager = StreakManager(services: ProdStreakServices(), configuration: Dependencies.streakConfiguration, logger: logManager)
            progressManager = ProgressManager(services: ProdProgressServices(), configuration: Dependencies.progressConfiguration, logger: logManager)
        }
        switch config {
        case .mock:
            pushManager = PushManager(
                service: MockLocalNotificationService(),
                logManager: logManager
            )
            liveActivityScheduler = MockFocusLiveActivityScheduler()
        case .dev, .prod:
            pushManager = PushManager(
                service: SystemLocalNotificationService(),
                logManager: logManager,
                userDefaults: .standard
            )
            liveActivityScheduler = SystemFocusLiveActivityScheduler()
        }
        soundEffectManager = SoundEffectManager(logger: logManager)
        switch config {
        case .mock:
            let snapshot: LocalAppSnapshot
            if let snapshotOverride {
                snapshot = snapshotOverride
            } else if ProcessInfo.processInfo.arguments.contains("HOME_FLOW")
                || ProcessInfo.processInfo.arguments.contains("FOCUS_PROGRESS_FLOW") {
                snapshot = LocalAppSnapshot.homeFlowMock
            } else if ProcessInfo.processInfo.arguments.contains("REWARD_FLOW") {
                snapshot = LocalAppSnapshot.rewardFlowMock
            } else {
                snapshot = LocalAppSnapshot.mock
            }
            repository = MockLocalAppRepository(snapshot: snapshot)
        case .dev, .prod:
            repository = LocalFileRepository(persistence: LocalFileRepositoryPersistence())
        }
        todayManager = TodayManager(
            repository: repository,
            notificationScheduler: pushManager,
            userDefaults: Self.todayUserDefaults(for: config)
        )
        focusManager = FocusManager(
            repository: repository,
            notificationScheduler: pushManager,
            liveActivityScheduler: liveActivityScheduler
        )
        rewardManager = RewardManager(
            repository: repository,
            notificationScheduler: pushManager
        )
        
        let container = DependencyContainer()
        container.register(AuthManager.self, service: authManager)
        container.register(UserManager.self, service: userManager)
        container.register(LogManager.self, service: logManager)
        container.register(ABTestManager.self, service: abTestManager)
        container.register(PurchaseManager.self, service: purchaseManager)
        container.register(AppState.self, service: appState)
        container.register(PushManager.self, service: pushManager)
        container.register(HapticManager.self, service: hapticManager)
        container.register(SoundEffectManager.self, service: soundEffectManager)
        container.register(StreakManager.self, key: Dependencies.streakConfiguration.streakKey, service: streakManager)
        container.register(ProgressManager.self, key: Dependencies.progressConfiguration.progressKey, service: progressManager)
        container.register(TodayManager.self, service: todayManager)
        container.register(FocusManager.self, service: focusManager)
        container.register(RewardManager.self, service: rewardManager)
        container.register(SupabaseClientProviding.self, service: supabaseService)
        container.register(SocialManager.self, service: socialManager)
        container.register(EmailAuthServicing.self, service: emailAuthService)

        self.container = container
        
        SwiftfulRoutingLogger.enableLogging(logger: logManager)
    }
    
    static let streakConfiguration = StreakConfiguration(
        streakKey: Constants.streakKey,
        eventsRequiredPerDay: 1,
        useServerCalculation: false,
        leewayHours: 0,
        freezeBehavior: .autoConsumeFreezes
    )
    
    static let progressConfiguration = ProgressConfiguration(
        progressKey: Constants.progressKey
    )

    private static func todayUserDefaults(for config: BuildConfiguration) -> UserDefaults? {
        switch config {
        case .mock: return nil
        case .dev, .prod: return .standard
        }
    }

}

@MainActor
class DevPreview {
    static let shared = DevPreview()
    private let dependencies: Dependencies

    func container(snapshotOverride: LocalAppSnapshot? = nil) -> DependencyContainer {
        if let snapshotOverride {
            return Dependencies(
                config: .mock(isSignedIn: true, addLogging: false),
                snapshotOverride: snapshotOverride
            ).container
        }
        return dependencies.container
    }

    init(isSignedIn: Bool = true) {
        self.dependencies = Dependencies(config: .mock(isSignedIn: isSignedIn, addLogging: false))
    }
}
