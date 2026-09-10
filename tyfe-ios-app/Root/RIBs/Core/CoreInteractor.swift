import SwiftUI

@MainActor
struct CoreInteractor: GlobalInteractor {
    private let appState: AppState
    private let authManager: AuthManager
    private let userManager: UserManager
    private let logManager: LogManager
    private let abTestManager: ABTestManager
    private let purchaseManager: PurchaseManager
    private let pushManager: PushManager
    private let hapticManager: HapticManager
    private let soundEffectManager: SoundEffectManager
    private let streakManager: StreakManager
    private let xpManager: ExperiencePointsManager
    private let progressManager: ProgressManager
    let todayManager: TodayManager
    let focusManager: FocusManager

    init(container: DependencyContainer) {
        self.appState = container.resolve(AppState.self)!
        self.authManager = container.resolve(AuthManager.self)!
        self.userManager = container.resolve(UserManager.self)!
        self.logManager = container.resolve(LogManager.self)!
        self.abTestManager = container.resolve(ABTestManager.self)!
        self.purchaseManager = container.resolve(PurchaseManager.self)!
        self.pushManager = container.resolve(PushManager.self)!
        self.hapticManager = container.resolve(HapticManager.self)!
        self.soundEffectManager = container.resolve(SoundEffectManager.self)!
        self.streakManager = container.resolve(StreakManager.self, key: Dependencies.streakConfiguration.streakKey)!
        self.xpManager = container.resolve(ExperiencePointsManager.self, key: Dependencies.xpConfiguration.experienceKey)!
        self.progressManager = container.resolve(ProgressManager.self, key: Dependencies.progressConfiguration.progressKey)!
        self.todayManager = container.resolve(TodayManager.self)!
        self.focusManager = container.resolve(FocusManager.self)!
    }
    
    // MARK: APP STATE
    
    var startingModuleId: String {
        appState.startingModuleId
    }

    // MARK: AuthManager
    
    var auth: UserAuthInfo? {
        authManager.auth
    }
    
    func getAuthId() throws -> String {
        try authManager.getAuthId()
    }
    
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await authManager.signInAnonymously()
    }

    func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await authManager.signInApple()
    }
    
    func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        throw AppError("Google sign-in is unavailable until Supabase authentication is integrated.")
    }
    
    // MARK: UserManager
    
    var currentUser: UserModel? {
        userManager.currentUser
    }
    
    func getCurrentUser() async throws -> UserModel {
        try await userManager.getUser()
    }
    
    func saveOnboardingComplete() async throws {
        try await userManager.saveOnboardingCompleteForCurrentUser()
    }
    
    func saveUserName(name: String) async throws {
        try await userManager.saveUserName(name: name)
    }
    
    func saveUserEmail(email: String) async throws {
        try await userManager.saveUserEmail(email: email)
    }
    
    func saveUserProfileImage(image: UIImage) async throws {
        try await userManager.saveUserProfileImage(image: image)
    }
    
    // MARK: LogManager
    
    func identifyUser(userId: String, name: String?, email: String?) {
        logManager.identifyUser(userId: userId, name: name, email: email)
    }
    
    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        logManager.addUserProperties(dict: dict, isHighPriority: isHighPriority)
    }
    
    func deleteUserProfile() {
        logManager.deleteUserProfile()
    }
    
    func trackEvent(eventName: String, parameters: [String: Any]? = nil, type: LogType = .analytic) {
        logManager.trackEvent(eventName: eventName, parameters: parameters, type: type)
    }
    
    func trackEvent(event: AnyLoggableEvent) {
        logManager.trackEvent(event: event)
    }

    func trackEvent(event: LoggableEvent) {
        logManager.trackEvent(event: event)
    }
    
    func trackScreenEvent(event: LoggableEvent) {
        logManager.trackEvent(event: event)
    }

    // MARK: PushManager
    
    func requestPushAuthorization() async throws -> Bool {
        try await pushManager.requestAuthorization()
    }
    
    func canRequestPushAuthorization() async -> Bool {
        await pushManager.canRequestAuthorization()
    }

    // MARK: ABTestManager
    
    var activeTests: ActiveABTests {
        abTestManager.activeTests
    }
        
    func override(updateTests: ActiveABTests) throws {
        try abTestManager.override(updateTests: updateTests)
    }
    
    // MARK: PurchaseManager
    
    var entitlements: [PurchasedEntitlement] {
        purchaseManager.entitlements
    }
    
    var isPremium: Bool {
        entitlements.hasActiveEntitlement
    }
    
    func getProducts(productIds: [String]) async throws -> [AnyProduct] {
        try await purchaseManager.getProducts(productIds: productIds)
    }
    
    func restorePurchase() async throws -> [PurchasedEntitlement] {
        try await purchaseManager.restorePurchase()
    }
    
    func purchaseProduct(productId: String) async throws -> [PurchasedEntitlement] {
        try await purchaseManager.purchaseProduct(productId: productId)
    }
    
    func updateProfileAttributes(attributes: PurchaseProfileAttributes) async throws {
        try await purchaseManager.updateProfileAttributes(attributes: attributes)
    }
    
    // MARK: Haptics
    
    func prepareHaptic(option: HapticOption) {
        hapticManager.prepareHaptic(option: option)
    }

    func prepareHaptics(options: [HapticOption]) {
        hapticManager.prepareHaptics(options: options)
    }

    func playHaptic(option: HapticOption) {
        hapticManager.playHaptic(option: option)
    }

    func playHaptics(options: [HapticOption]) {
        hapticManager.playHaptics(options: options)
    }

    func tearDownHaptic(option: HapticOption) {
        hapticManager.tearDownHaptic(option: option)
    }

    func tearDownHaptics(options: [HapticOption]) {
        hapticManager.tearDownHaptics(options: options)
    }

    func tearDownAllHaptics() {
        hapticManager.tearDownAllHaptics()
    }
    
    // MARK: Sound Effects

    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int = 1) {
        soundEffectManager.prepareSoundEffect(url: sound.url, simultaneousPlayers: simultaneousPlayers, volume: 1)
    }

    func tearDownSoundEffect(sound: SoundEffectFile) {
        soundEffectManager.tearDownSoundEffect(url: sound.url)
    }

    func playSoundEffect(sound: SoundEffectFile) {
        soundEffectManager.playSoundEffect(url: sound.url)
    }

    // MARK: StreakManager

    var currentStreakData: CurrentStreakData {
        streakManager.currentStreakData
    }

    @discardableResult
    func addStreakEvent(metadata: [String: GamificationDictionaryValue] = [:]) async throws -> StreakEvent {
        try await streakManager.addStreakEvent(metadata: metadata)
    }

    func getAllStreakEvents() async throws -> [StreakEvent] {
        try await streakManager.getAllStreakEvents()
    }

    func deleteAllStreakEvents() async throws {
        try await streakManager.deleteAllStreakEvents()
    }

    @discardableResult
    func addStreakFreeze(id: String, dateExpires: Date? = nil) async throws -> StreakFreeze {
        try await streakManager.addStreakFreeze(id: id, dateExpires: dateExpires)
    }
    
    func useStreakFreezes() async throws {
        try await streakManager.useStreakFreezes()
    }

    func getAllStreakFreezes() async throws -> [StreakFreeze] {
        try await streakManager.getAllStreakFreezes()
    }

    func recalculateStreak() {
        streakManager.recalculateStreak()
    }

    // MARK: ExperiencePointsManager

    var currentExperiencePointsData: CurrentExperiencePointsData {
        xpManager.currentExperiencePointsData
    }

    @discardableResult
    func addExperiencePoints(points: Int, metadata: [String: GamificationDictionaryValue] = [:]) async throws -> ExperiencePointsEvent {
        try await xpManager.addExperiencePoints(points: points, metadata: metadata)
    }

    func getAllExperiencePointsEvents() async throws -> [ExperiencePointsEvent] {
        try await xpManager.getAllExperiencePointsEvents()
    }

    func getAllExperiencePointsEvents(forField field: String, equalTo value: GamificationDictionaryValue) async throws -> [ExperiencePointsEvent] {
        try await xpManager.getAllExperiencePointsEvents(forField: field, equalTo: value)
    }

    func deleteAllExperiencePointsEvents() async throws {
        try await xpManager.deleteAllExperiencePointsEvents()
    }

    func recalculateExperiencePoints() {
        xpManager.recalculateExperiencePoints()
    }

    // MARK: ProgressManager

    func getProgress(id: String) -> Double {
        progressManager.getProgress(id: id)
    }

    func getProgressItem(id: String) -> ProgressItem? {
        progressManager.getProgressItem(id: id)
    }

    func getAllProgress() -> [String: Double] {
        progressManager.getAllProgress()
    }

    func getAllProgressItems() -> [ProgressItem] {
        progressManager.getAllProgressItems()
    }

    func getProgressItems(forMetadataField metadataField: String, equalTo value: GamificationDictionaryValue) -> [ProgressItem] {
        progressManager.getProgressItems(forMetadataField: metadataField, equalTo: value)
    }

    func getMaxProgress(forMetadataField metadataField: String, equalTo value: GamificationDictionaryValue) -> Double {
        progressManager.getMaxProgress(forMetadataField: metadataField, equalTo: value)
    }

    @discardableResult
    func addProgress(id: String, value: Double, metadata: [String: GamificationDictionaryValue]? = nil) async throws -> ProgressItem {
        try await progressManager.addProgress(id: id, value: value, metadata: metadata)
    }

    func deleteProgress(id: String) async throws {
        try await progressManager.deleteProgress(id: id)
    }

    func deleteAllProgress() async throws {
        try await progressManager.deleteAllProgress()
    }

    // MARK: Phase 1 Planning

    var phase1Activities: [ActivityModel] {
        todayManager.activities
    }

    var phase1DailyPlan: DailyPlanModel? {
        todayManager.dailyPlan
    }

    var phase1CompletedSessionCount: Int {
        todayManager.completedSessionCount
    }

    var phase1CompletedSessionCounts: [String: Int] {
        guard let dailyPlan = todayManager.dailyPlan else { return [:] }
        return Dictionary(uniqueKeysWithValues: dailyPlan.planItems.map { item in
            (item.activityId, todayManager.completedSessionCount(for: item.activityId))
        })
    }

    var phase1RewardCredits: Int {
        todayManager.rewardCredits
    }

    var phase1Progression: ProgressionSnapshotModel {
        todayManager.progression
    }

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel? {
        todayManager.createActivity(name: name, category: category, colorToken: colorToken)
    }

    @discardableResult
    func acceptPhase1DailyPlan(
        intendedSessionCount: Int,
        activityIds: [String],
        timeBlocks: [PlanTimeBlockModel]?
    ) -> DailyPlanModel {
        todayManager.acceptDailyPlan(
            intendedSessionCount: intendedSessionCount,
            activityIds: activityIds,
            timeBlocks: timeBlocks
        )
    }

    @discardableResult
    func startPhase1FocusSession(activityId: String) -> FocusSessionModel? {
        focusManager.startFocusSession(activityId: activityId)
    }

    @discardableResult
    func addPhase1ActivityToDailyPlan(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        todayManager.addActivityToDailyPlan(
            activityId: activityId,
            sessionCount: sessionCount
        )
    }

    @discardableResult
    func updatePhase1DailyPlanItemCount(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        todayManager.updateDailyPlanItemCount(
            activityId: activityId,
            sessionCount: sessionCount
        )
    }

    @discardableResult
    func removePhase1ActivityFromDailyPlan(activityId: String) -> DailyPlanModel? {
        todayManager.removeActivityFromDailyPlan(activityId: activityId)
    }

    // MARK: Home Dashboard

    var dashboardState: HomeDashboardState {
        let activeFocusSession = focusManager.activeFocusSession
        let activeFocusActivity = activeFocusSession.flatMap { session in
            todayManager.activities.first { activity in
                activity.activityId == session.activityId
            }
        }

        return HomeDashboardState(
            nextActivity: nextHomeActivity,
            plannedSessionCount: todayManager.dailyPlan?.intendedSessionCount ?? 0,
            completedSessionCount: todayManager.completedSessionCount,
            rewardCredits: todayManager.rewardCredits,
            activeFocusSession: activeFocusSession,
            activeFocusActivity: activeFocusActivity
        )
    }

    @discardableResult
    func startFocusFromHome() -> FocusSessionModel? {
        if let activeFocusSession = focusManager.activeFocusSession {
            return activeFocusSession
        }

        guard let nextHomeActivity else { return nil }
        return focusManager.startFocusSession(activityId: nextHomeActivity.activityId)
    }

    private var nextHomeActivity: ActivityModel? {
        guard let dailyPlan = todayManager.dailyPlan else { return nil }

        return dailyPlan.planItems.compactMap { item in
            guard todayManager.completedSessionCount(for: item.activityId) < item.plannedSessionCount else {
                return nil
            }
            return todayManager.activities.first { activity in
                activity.activityId == item.activityId && !activity.isArchived
            }
        }.first
    }

    // MARK: SHARED

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
        // Run all logins in parallel
        async let userLogin: Void = userManager.signIn(auth: user, isNewUser: isNewUser)
        async let purchaseLogin: ([PurchasedEntitlement]) = purchaseManager.logIn(
            userId: user.uid,
            userAttributes: PurchaseProfileAttributes(
                email: user.email,
                mixpanelDistinctId: Constants.mixpanelDistinctId,
                firebaseAppInstanceId: nil
            )
        )
        async let streakLogin: Void = streakManager.logIn(userId: user.uid)
        async let xpLogin: Void = xpManager.logIn(userId: user.uid)
        async let progressLogin: Void = progressManager.logIn(userId: user.uid)

        let (_, _, _, _, _) = await (try userLogin, try purchaseLogin, try streakLogin, try xpLogin, try progressLogin)

        // Add user properties
        logManager.addUserProperties(dict: Utilities.eventParameters, isHighPriority: false)
    }

    func signOut() async throws {
        try authManager.signOut()
        try await purchaseManager.logOut()
        userManager.signOut()
        streakManager.logOut()
        xpManager.logOut()
        await progressManager.logOut()
    }
    
    func deleteAccount() async throws {
        guard let auth else {
            throw AppError("Auth not found.")
        }
        
        var option: SignInOption = .anonymous
        if auth.authProviders.contains(.apple) {
            option = .apple
        } else if auth.authProviders.contains(.google) {
            throw AppError("Google account deletion is unavailable until Supabase authentication is integrated.")
        }
        
        // Delete auth
        try await authManager.deleteAccountWithReauthentication(option: option, revokeToken: false) {
            // Delete the local user profile before revoking authentication.
            try await userManager.deleteCurrentUser()
        }
        
        // Delete Purchases (RevenueCat)
        try await purchaseManager.logOut()
        
        // Delete logs (Mixpanel)
        logManager.deleteUserProfile()
    }

}
