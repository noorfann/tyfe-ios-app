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
        let appState: AppState
        let logManager: LogManager
        let pushManager: PushManager
        let liveActivityScheduler: FocusLiveActivityScheduling
        let rewardLiveActivityScheduler: RewardLiveActivityScheduling
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
        let profileService: any ProfileServicing
        
        switch config {
        case .mock(isSignedIn: let isSignedIn, addLogging: let addLogging):
            logManager = LogManager(services: addLogging ? [
                ConsoleService(printParameters: true, system: .stdout)
            ] : [])
            let mockEmailService = Self.makeMockEmailService(isSignedIn: isSignedIn)
            authManager = AuthManager(service: mockEmailService, logger: logManager)
            emailAuthService = mockEmailService
            profileService = MockProfileService(initialName: { userId in
                guard let auth = authManager.auth, auth.uid == userId else { return nil }
                return auth.displayName ?? "Friend"
            })
            supabaseService = MockSupabaseClientService()
            userManager = UserManager(userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: isSignedIn ? UserModel.mock : nil),
                managerKey: UserManager.persistenceKey,
                enableLocalPersistence: false,
                logger: logManager
            ), profileService: profileService, currentAuthUserId: { authManager.auth?.uid },
                hasPendingRegistration: { emailAuthService.pendingRegistration != nil })
            
            // Note: configure AB tests for UI tests here
            //
            // let isInTest = ProcessInfo.processInfo.arguments.contains("SOMETEST")
            let abTestService = MockABTestService(
                boolTest: nil,
                enumTest: nil
            )
            abTestManager = ABTestManager(service: abTestService, logManager: logManager)
            appState = AppState(
                startingModuleId: isSignedIn ? Constants.tabbarModuleId : "",
                auth: mockEmailService.authenticatedUser,
                hasPendingRegistration: mockEmailService.pendingRegistration != nil,
                userDefaults: Utilities.isUITesting && ProcessInfo.processInfo.arguments.contains("WELCOME_FLOW") ? .standard : nil
            )
            hapticManager = HapticManager(logger: logManager)
            streakManager = StreakManager(services: MockStreakServices(), configuration: Dependencies.streakConfiguration, logger: logManager)
            progressManager = ProgressManager(services: MockProgressServices(), configuration: Dependencies.progressConfiguration, logger: logManager)
            socialManager = SocialManager(
                service: MockSocialService(currentUserId: UserAuthInfo.mock().uid, profileService: profileService),
                logManager: logManager,
                profileService: profileService
            )
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
                profileService = SupabaseProfileService(client: liveService.client)
                supabaseService = liveService
                let liveAuthService = SupabaseAuthService(client: liveService.client, profileService: profileService)
                authManager = AuthManager(service: liveAuthService, logger: logManager)
                socialManager = SocialManager(
                    service: SupabaseSocialService(client: liveService.client),
                    logManager: logManager, userDefaults: .standard, profileService: profileService
                )
                emailAuthService = SupabaseEmailAuthService(
                    client: liveService.client,
                    store: EmailRegistrationStore(defaults: .standard, key: "tyfe.email-registration.\(configuration.url.host ?? "live")"),
                    waitForAuthReset: { await liveAuthService.waitForSessionPreparation() }
                )
            } else {
                supabaseService = MockSupabaseClientService()
                profileService = UnavailableProfileService()
                authManager = AuthManager(service: MockAuthService(user: nil), logger: logManager)
                socialManager = SocialManager(
                    service: MockSocialService(profileService: profileService),
                    logManager: logManager, userDefaults: .standard, profileService: profileService
                )
                emailAuthService = UnavailableEmailAuthService()
            }
            #else
            supabaseService = MockSupabaseClientService()
            profileService = UnavailableProfileService()
            authManager = AuthManager(service: MockAuthService(user: nil), logger: logManager)
            socialManager = SocialManager(
                service: MockSocialService(profileService: profileService),
                logManager: logManager, profileService: profileService
            )
            emailAuthService = UnavailableEmailAuthService()
            #endif
            userManager = UserManager(userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: nil),
                managerKey: UserManager.persistenceKey,
                enableLocalPersistence: true,
                logger: logManager
            ), profilePersistence: FileManagerDocumentPersistence<UserModel>(),
                profileService: profileService, currentAuthUserId: { authManager.auth?.uid },
                hasPendingRegistration: { emailAuthService.pendingRegistration != nil },
                cleanupDefaults: .standard)
            abTestManager = ABTestManager(service: LocalABTestService(), logManager: logManager)
            hapticManager = HapticManager(logger: logManager)
            appState = AppState(auth: authManager.auth, hasPendingRegistration: emailAuthService.pendingRegistration != nil)
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
            rewardLiveActivityScheduler = MockRewardLiveActivityScheduler()
        case .dev, .prod:
            pushManager = PushManager(
                service: SystemLocalNotificationService(),
                logManager: logManager,
                userDefaults: .standard
            )
            liveActivityScheduler = SystemFocusLiveActivityScheduler()
            rewardLiveActivityScheduler = SystemRewardLiveActivityScheduler()
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
            notificationScheduler: pushManager,
            liveActivityScheduler: rewardLiveActivityScheduler
        )
        
        let container = DependencyContainer()
        container.register(AuthManager.self, service: authManager)
        container.register(UserManager.self, service: userManager)
        container.register(LogManager.self, service: logManager)
        container.register(ABTestManager.self, service: abTestManager)
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
        container.register(ProfileServicing.self, service: profileService)
        container.register(LocalAppRepository.self, service: repository)
        container.register(SocialManager.self, service: socialManager)
        container.register(EmailAuthServicing.self, service: emailAuthService)

        self.container = container
        
        SwiftfulRoutingLogger.enableLogging(logger: logManager)
    }
    
    private static func makeMockEmailService(isSignedIn: Bool) -> MockEmailAuthService {
        let arguments = ProcessInfo.processInfo.arguments
        guard Utilities.isUITesting, arguments.contains("SIGNUP_FLOW") || arguments.contains("WELCOME_FLOW") else {
            return MockEmailAuthService(user: isSignedIn ? .mock() : nil)
        }
        let store = EmailRegistrationStore(defaults: .standard, key: "tyfe.ui-tests.email-registration")
        if arguments.contains("RESET_SIGNUP") { try? store.save(nil) }
        if arguments.contains("RESET_WELCOME") {
            try? store.save(nil)
            UserDefaults.standard.removeObject(forKey: AppState.entryPhaseKey)
            UserDefaults.standard.removeObject(forKey: MockEmailAuthService.sessionKey)
        }
        if arguments.contains("WELCOME_FLOW") {
            let data = UserDefaults.standard.data(forKey: MockEmailAuthService.sessionKey)
            let user = data.flatMap { try? JSONDecoder().decode(UserAuthInfo.self, from: $0) }
            return MockEmailAuthService(user: user, store: store, sessionDefaults: .standard)
        }
        let pending = store.pending
        let verified = pending?.stage == .password || pending?.stage == .profile
        let user = UserAuthInfo(
            uid: pending?.userId ?? "mock-signup-guest",
            email: verified ? pending?.email : nil,
            isAnonymous: !verified,
            authProviders: verified ? [.email] : [],
            displayName: pending?.displayName
        )
        return MockEmailAuthService(user: user, store: store)
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
