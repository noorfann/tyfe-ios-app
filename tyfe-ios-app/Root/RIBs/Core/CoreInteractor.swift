import SwiftUI

@MainActor
struct CoreInteractor: GlobalInteractor {
    private let appState: AppState
    private let authManager: AuthManager
    private let emailAuthService: EmailAuthServicing
    private let userManager: UserManager
    private let logManager: LogManager
    private let abTestManager: ABTestManager
    private let pushManager: PushManager
    private let hapticManager: HapticManager
    private let soundEffectManager: SoundEffectManager
    private let streakManager: StreakManager
    private let progressManager: ProgressManager
    let todayManager: TodayManager
    let focusManager: FocusManager
    let rewardManager: RewardManager
    let socialManager: SocialManager

    init(container: DependencyContainer) {
        self.appState = container.resolve(AppState.self)!
        self.authManager = container.resolve(AuthManager.self)!
        self.emailAuthService = container.resolve(EmailAuthServicing.self)!
        self.userManager = container.resolve(UserManager.self)!
        self.logManager = container.resolve(LogManager.self)!
        self.abTestManager = container.resolve(ABTestManager.self)!
        self.pushManager = container.resolve(PushManager.self)!
        self.hapticManager = container.resolve(HapticManager.self)!
        self.soundEffectManager = container.resolve(SoundEffectManager.self)!
        self.streakManager = container.resolve(StreakManager.self, key: Dependencies.streakConfiguration.streakKey)!
        self.progressManager = container.resolve(ProgressManager.self, key: Dependencies.progressConfiguration.progressKey)!
        self.todayManager = container.resolve(TodayManager.self)!
        self.focusManager = container.resolve(FocusManager.self)!
        self.rewardManager = container.resolve(RewardManager.self)!
        self.socialManager = container.resolve(SocialManager.self)!
    }
    
    // MARK: APP STATE
    
    var startingModuleId: String {
        appState.startingModuleId
    }

    var entryPhase: AppEntryPhase { appState.entryPhase }

    func setEntryPhase(_ phase: AppEntryPhase) { appState.setEntryPhase(phase) }

    func prepareEntryTransition(to phase: AppEntryPhase) { appState.prepareEntryTransition(to: phase) }

    func completeEntryTransition() { appState.completeEntryTransition() }

    func prepareGuestForSignup() async throws {
        _ = try await emailAuthService.restoreRegistration()
        if emailAuthService.authenticatedUser == nil {
            let result = try await authManager.signInAnonymously()
            try await logIn(user: result.user, isNewUser: result.isNewUser)
        }
        guard let user = emailAuthService.authenticatedUser,
              user.isAnonymous || pendingEmailRegistration != nil else { throw EmailAuthError.alreadySignedIn }
    }

    var isFocusScreenVisible: Bool {
        appState.isFocusScreenVisible
    }

    func setFocusScreenVisible(_ isVisible: Bool) {
        appState.isFocusScreenVisible = isVisible
    }

    var colorScheme: ColorScheme {
        appState.colorScheme
    }

    func setDarkMode(_ isDark: Bool) {
        appState.setDarkMode(isDark)
    }

    func reconcileFocusLiveActivity() {
        focusManager.reconcileLiveActivity()
    }

    func reconcileRewardLiveActivity() {
        rewardManager.reconcileLiveActivity()
    }

    // MARK: AuthManager
    
    var auth: UserAuthInfo? {
        authManager.auth
    }

    var suggestedDisplayName: String? {
        userManager.currentUser?.commonNameCalculated
    }
    
    func getAuthId() throws -> String {
        try authManager.getAuthId()
    }
    
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await authManager.signInAnonymously()
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await emailAuthService.signIn(email: email, password: password)
    }
    
    // MARK: UserManager
    
    var currentUser: UserModel? {
        guard let user = userManager.currentUser, user.userId == auth?.uid else { return nil }
        return user
    }

    func getCurrentUser() async throws -> UserModel {
        try await userManager.getUser()
    }
    
    func saveOnboardingComplete() async throws {
        try await userManager.saveOnboardingCompleteForCurrentUser()
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

    var phase1Projects: [ProjectModel] {
        todayManager.projects
    }

    var phase1SelectedProjectId: String? {
        todayManager.selectedProjectId
    }

    var phase1DailyPlan: DailyPlanModel? {
        todayManager.dailyPlan
    }

    var phase1CurrentLocalDay: LocalDay {
        todayManager.currentLocalDay
    }

    var phase1EarliestRecordedLocalDay: LocalDay? {
        todayManager.earliestRecordedLocalDay
    }

    var phase1CompletedSessionCount: Int {
        todayManager.completedSessionCount
    }

    func phase1DailyPlan(for localDay: LocalDay) -> DailyPlanModel? {
        todayManager.dailyPlan(for: localDay)
    }

    func phase1CompletedSessionCount(on localDay: LocalDay) -> Int {
        todayManager.completedSessionCount(on: localDay)
    }

    func phase1VisiblePlanItems(on localDay: LocalDay) -> [DailyPlanItemModel] {
        todayManager.visiblePlanItems(on: localDay)
    }

    func phase1VisibleCompletedSessionCount(on localDay: LocalDay) -> Int {
        todayManager.visibleCompletedSessionCount(on: localDay)
    }

    var hasSeenDeckSwipeCoachmark: Bool {
        todayManager.hasSeenDeckSwipeCoachmark
    }

    func markDeckSwipeCoachmarkSeen() {
        todayManager.markDeckSwipeCoachmarkSeen()
    }

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel? {
        todayManager.createActivity(name: name, category: category, colorToken: colorToken, type: .session)
    }

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?,
        type: ActivityType
    ) -> ActivityModel? {
        todayManager.createActivity(name: name, category: category, colorToken: colorToken, type: type)
    }

    @discardableResult
    func updatePhase1Activity(
        activityId: String,
        name: String,
        category: ActivityCategory?
    ) -> ActivityModel? {
        todayManager.updateActivity(
            activityId: activityId,
            name: name,
            category: category
        )
    }

    @discardableResult
    func setPhase1ActivityRecurrence(
        activityId: String,
        recurrence: ActivityRecurrenceModel?
    ) -> ActivityModel? {
        todayManager.setActivityRecurrence(activityId: activityId, recurrence: recurrence)
    }

    func setPhase1SelectedProjectId(_ projectId: String?) {
        todayManager.setSelectedProjectId(projectId)
    }

    @discardableResult
    func acceptPhase1DailyPlan(
        intendedSessionCount: Int,
        activityIds: [String],
        timeBlocks: [PlanTimeBlockModel]?
    ) -> DailyPlanModel {
        let plan = todayManager.acceptDailyPlan(
            intendedSessionCount: intendedSessionCount,
            activityIds: activityIds,
            timeBlocks: timeBlocks
        )
        scheduleSharedProgressSync()
        return plan
    }

    @discardableResult
    func startPhase1FocusSession(activityId: String) -> FocusSessionModel? {
        guard !isRewardInProgress else { return nil }
        return focusManager.startFocusSession(activityId: activityId)
    }

    @discardableResult
    func abandonPhase1FocusSession(focusSessionId: String) -> FocusSessionModel? {
        try? focusManager.abandonFocusSession(focusSessionId: focusSessionId)
    }

    @discardableResult
    func addPhase1ActivityToDailyPlan(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        let plan = todayManager.addActivityToDailyPlan(
            activityId: activityId,
            sessionCount: sessionCount
        )
        scheduleSharedProgressSync()
        return plan
    }

    @discardableResult
    func updatePhase1DailyPlanItemCount(
        activityId: String,
        sessionCount: Int
    ) -> DailyPlanModel? {
        let plan = todayManager.updateDailyPlanItemCount(
            activityId: activityId,
            sessionCount: sessionCount
        )
        scheduleSharedProgressSync()
        return plan
    }

    @discardableResult
    func removePhase1ActivityFromDailyPlan(activityId: String) -> DailyPlanModel? {
        let plan = todayManager.removeActivityFromDailyPlan(activityId: activityId)
        scheduleSharedProgressSync()
        return plan
    }

    // MARK: Home Dashboard

    var dashboardState: HomeDashboardState {
        let currentDay = todayManager.currentLocalDay
        let activeFocusSession = focusManager.activeFocusSession
        let activeFocusActivity = activeFocusSession.flatMap { session in
            todayManager.activities.first { activity in
                activity.activityId == session.activityId
            }
        }

        return HomeDashboardState(
            nextActivity: nextHomeActivity,
            plannedSessionCount: todayManager.plannedUnitCount(.session, on: currentDay),
            completedSessionCount: todayManager.visibleCompletedSessionCount(on: currentDay),
            plannedChecklistItemCount: todayManager.plannedUnitCount(.checklist, on: currentDay),
            completedChecklistItemCount: todayManager.visibleCompletedChecklistItemCount(on: currentDay),
            activeFocusSession: activeFocusSession,
            activeFocusActivity: activeFocusActivity
        )
    }

    @discardableResult
    func startFocusFromHome() -> FocusSessionModel? {
        guard !isRewardInProgress else { return nil }

        if let activeFocusSession = focusManager.activeFocusSession {
            return activeFocusSession
        }

        guard let nextHomeActivity, nextHomeActivity.type == .session else { return nil }
        return focusManager.startFocusSession(activityId: nextHomeActivity.activityId)
    }

    private var nextHomeActivity: ActivityModel? {
        let currentDay = todayManager.currentLocalDay
        return todayManager.visiblePlanItems(on: currentDay).compactMap { item -> ActivityModel? in
            guard let activity = todayManager.activities.first(where: { candidate in
                candidate.activityId == item.activityId && !candidate.isArchived
            }) else {
                return nil
            }
            guard todayManager.completedItems(for: item, on: currentDay) < item.plannedSessionCount else {
                return nil
            }
            return activity
        }.first
    }

    // MARK: Rewards

    var rewards: [RewardModel] {
        rewardManager.rewards
    }

    var rewardCredits: Decimal {
        rewardManager.rewardCredits
    }

    func synchronizeRewardCreditDay() {
        rewardManager.synchronizeCreditDay()
    }

    func synchronizeCurrentDay() {
        rewardManager.synchronizeCreditDay()
        todayManager.materializeCurrentDay()
    }

    var activeRewardClaim: RewardClaimModel? {
        rewardManager.activeRewardClaim
    }

    var isRewardInProgress: Bool {
        activeRewardClaim?.state == .active
    }

    var hasLiveFocusSession: Bool {
        focusManager.activeFocusSession != nil
    }

    var isFocusInProgress: Bool {
        guard let session = focusManager.activeFocusSession else { return false }
        return session.state == .running || session.isResting
    }

    func activity(forFocusSession session: FocusSessionModel) -> ActivityModel? {
        todayManager.activities.first { $0.activityId == session.activityId }
    }

    var rewardClaims: [RewardClaimModel] {
        rewardManager.rewardClaims
    }

    @discardableResult
    func createCustomReward(name: String, durationTier: RewardDurationTier) -> RewardModel? {
        rewardManager.createCustomReward(name: name, durationTier: durationTier)
    }

    @discardableResult
    func createRewardClaim(
        rewardId: String,
        durationTier: RewardDurationTier
    ) throws -> RewardClaimModel {
        guard !hasLiveFocusSession else {
            throw RewardManagerError.focusSessionInProgress
        }
        return try rewardManager.createRewardClaim(rewardId: rewardId, durationTier: durationTier)
    }

    @discardableResult
    func startRewardClaim(rewardClaimId: String) throws -> RewardClaimModel {
        guard !hasLiveFocusSession else {
            throw RewardManagerError.focusSessionInProgress
        }
        return try rewardManager.startRewardClaim(rewardClaimId: rewardClaimId)
    }

    @discardableResult
    func refreshRewardClaim() throws -> RewardClaimModel? {
        try rewardManager.refreshRewardClaim()
    }

    // MARK: SHARED

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
        guard auth?.uid == user.uid else { throw EmailAuthError.sessionChanged }
        socialManager.prepareAccount(userId: user.uid)
        // Reconcile the profile while refreshing optional integrations independently.
        async let userLogin: Void = userManager.signIn(auth: user, isNewUser: isNewUser)
        async let optionalLogin: Void = refreshOptionalAccountServices(user: user)
        try await userLogin
        await optionalLogin

        // Add user properties
        logManager.addUserProperties(dict: Utilities.eventParameters, isHighPriority: false)

    }

    func signOut() async throws {
        try authManager.signOut()
        appState.setEntryPhase(.welcome)
        resetRegistrationAfterSignOut()
        userManager.signOut()
        socialManager.signOut()
        streakManager.logOut()
        await progressManager.logOut()
    }
    
    func deleteAccount() async throws {
        guard let auth else {
            throw AppError("Auth not found.")
        }
        
        var option: SignInOption = .anonymous
        if auth.authProviders.contains(.apple) {
            option = .apple
        }
        
        // Storage cleanup must finish while authenticated; failed cleanup leaves deletion retryable.
        try await authManager.deleteAccountWithReauthentication(option: option, revokeToken: false) {
            guard self.auth?.uid == auth.uid else { throw EmailAuthError.sessionChanged }
            try await userManager.removeAllProfilePhotos()
            guard self.auth?.uid == auth.uid else { throw EmailAuthError.sessionChanged }
        }
        guard userManager.currentUser == nil || userManager.currentUser?.userId == auth.uid else {
            throw EmailAuthError.sessionChanged
        }
        // Keep local identity until remote deletion succeeds, so an RPC failure can be retried.
        do {
            try await userManager.deleteCurrentUser()
        } catch {
            userManager.signOut()
            logManager.trackEvent(eventName: "Account_LocalProfileCleanupFailed", parameters: nil, type: .warning)
        }
        appState.setEntryPhase(.welcome)
        resetRegistrationAfterSignOut()
        socialManager.signOut()

        // Delete logs (Mixpanel)
        logManager.deleteUserProfile()
    }

}

extension CoreInteractor {
    var canEditProfile: Bool {
        auth?.isAnonymous == false && pendingEmailRegistration == nil
    }

    var profilePhotoURL: URL? {
        guard currentUser?.userId == auth?.uid else { return nil }
        return userManager.profilePhotoURL
    }

    var profileSessionGeneration: Int {
        userManager.profileSessionGeneration
    }

    func refreshProfile() async throws {
        guard canEditProfile else { throw AppError("Finish creating your account to edit your profile.") }
        try await userManager.refreshProfile()
    }

    func saveProfile(name: String, photo: ProfilePhotoChange) async throws {
        guard canEditProfile else { throw AppError("Finish creating your account to edit your profile.") }
        try await userManager.saveProfile(name: name, photo: photo)
    }

    private func resetRegistrationAfterSignOut() {
        do { try emailAuthService.resetRegistrationAfterSignOut() } catch {
            logManager.trackEvent(eventName: "Account_RegistrationResetFailed", parameters: nil, type: .warning)
        }
    }

    var pendingEmailRegistration: PendingEmailRegistration? {
        emailAuthService.pendingRegistration
    }

    func restoreEmailRegistration() async throws -> PendingEmailRegistration? {
        try await emailAuthService.restoreRegistration()
    }

    func beginEmailRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration {
        try await emailAuthService.beginRegistration(email: email, displayName: displayName)
    }

    func verifyEmailRegistrationCode(_ code: String) async throws -> PendingEmailRegistration {
        try await emailAuthService.verifyRegistrationCode(code)
    }

    func resendEmailRegistrationCode() async throws -> PendingEmailRegistration {
        try await emailAuthService.resendRegistrationCode()
    }

    func finishEmailRegistration(password: String) async throws {
        let user = try await emailAuthService.finishRegistration(password: password)
        try await userManager.reconcileRegistration(auth: user)
        guard emailAuthService.authenticatedUser?.uid == user.uid else { throw EmailAuthError.sessionChanged }
        try emailAuthService.acknowledgeRegistrationComplete()
        // Account creation is complete. Optional integrations cannot turn it into a failed signup.
        Task { await refreshOptionalAccountServices(user: user) }
    }

    private func refreshOptionalAccountServices(user: UserAuthInfo) async {
        guard auth?.uid == user.uid else { return }
        async let streak: Void = refreshStreakAccount(userId: user.uid)
        async let progress: Void = refreshProgressAccount(userId: user.uid)
        _ = await (streak, progress)
        guard auth?.uid == user.uid else { return }
        await syncSocialRealtime()
    }

    private func refreshStreakAccount(userId: String) async {
        do { try await streakManager.logIn(userId: userId) } catch {
            logManager.trackEvent(eventName: "Account_StreakRefreshFailed", parameters: nil, type: .warning)
        }
    }

    private func refreshProgressAccount(userId: String) async {
        do { try await progressManager.logIn(userId: userId) } catch {
            logManager.trackEvent(eventName: "Account_ProgressRefreshFailed", parameters: nil, type: .warning)
        }
    }

}
