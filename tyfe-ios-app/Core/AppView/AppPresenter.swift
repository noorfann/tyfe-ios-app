//
//  AppPresenter.swift
//
//
//
//
import SwiftUI
import SwiftfulUtilities

@Observable
@MainActor
class AppPresenter {
    
    private let interactor: AppViewInteractor

    private(set) var activeCheerKinds: [CheerKind] = []
    @ObservationIgnored private var cheerBatchTask: Task<Void, Never>?
    @ObservationIgnored private var isApplicationActive = false

    private static let cheerBatchDelay = Duration.milliseconds(250)
    
    var auth: UserAuthInfo? {
        interactor.auth
    }
    
    var colorScheme: ColorScheme {
        interactor.colorScheme
    }

    var pendingReceivedCheerCount: Int {
        interactor.pendingReceivedCheerCount
    }
    
    func toggleColorScheme() {
        interactor.toggleColorScheme()
    }
    
    init(interactor: AppViewInteractor) {
        self.interactor = interactor
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        stopCheerCelebration()
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onScenePhaseChanged(_ scenePhase: ScenePhase) {
        guard scenePhase == .active else {
            stopCheerCelebration()
            return
        }
        interactor.discardPendingReceivedCheers()
        interactor.synchronizeRewardCreditDay()
        interactor.reconcileFocusLiveActivity()
        isApplicationActive = true
    }

    func onPendingReceivedCheersChanged() {
        guard isApplicationActive else {
            interactor.discardPendingReceivedCheers()
            return
        }
        schedulePendingCheerCelebration()
    }

    func presentPendingCheers() {
        guard isApplicationActive, activeCheerKinds.isEmpty else { return }
        let receivedCheers = interactor.consumePendingReceivedCheers()
        activeCheerKinds = receivedCheers.map(\.kind)
    }

    func onCheerCelebrationCompleted() {
        activeCheerKinds = []
        schedulePendingCheerCelebration()
    }

    func showATTPromptIfNeeded() async {
        #if !DEBUG
        let status = await AppTrackingTransparencyHelper.requestTrackingAuthorization()
        interactor.trackEvent(event: Event.attStatus(dict: status.eventParameters))
        #endif
    }
    
    func checkUserStatus() async {
        if let user = interactor.auth {
            // User is authenticated
            interactor.trackEvent(event: Event.existingAuthStart)
            
            do {
                try await interactor.logIn(user: user, isNewUser: false)
            } catch {
                interactor.trackEvent(event: Event.existingAuthFail(error: error))
                try? await Task.sleep(for: .seconds(5))
                await checkUserStatus()
            }
        } else {
            // User is not authenticated
            interactor.trackEvent(event: Event.anonAuthStart)

            do {
                let result = try await interactor.signInAnonymously()
                
                // log in to app
                interactor.trackEvent(event: Event.anonAuthSuccess)
                
                // Log in
                try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)

            } catch {
                interactor.trackEvent(event: Event.anonAuthFail(error: error))
                try? await Task.sleep(for: .seconds(5))
                await checkUserStatus()
            }
        }
    }

    private func schedulePendingCheerCelebration() {
        guard activeCheerKinds.isEmpty,
              pendingReceivedCheerCount > 0,
              cheerBatchTask == nil else { return }
        cheerBatchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.cheerBatchDelay)
            } catch {
                return
            }
            guard let self else { return }
            cheerBatchTask = nil
            presentPendingCheers()
        }
    }

    private func stopCheerCelebration() {
        isApplicationActive = false
        cheerBatchTask?.cancel()
        cheerBatchTask = nil
        activeCheerKinds = []
        interactor.discardPendingReceivedCheers()
    }
    
}

extension AppPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case existingAuthStart
        case existingAuthFail(error: Error)
        case anonAuthStart
        case anonAuthSuccess
        case anonAuthFail(error: Error)
        case attStatus(dict: [String: Any])

        var eventName: String {
            switch self {
            case .onAppear:             return "AppView_Appear"
            case .onDisappear:          return "AppView_Disappear"
            case .existingAuthStart:    return "AppView_ExistingAuth_Start"
            case .existingAuthFail:     return "AppView_ExistingAuth_Fail"
            case .anonAuthStart:        return "AppView_AnonAuth_Start"
            case .anonAuthSuccess:      return "AppView_AnonAuth_Success"
            case .anonAuthFail:         return "AppView_AnonAuth_Fail"
            case .attStatus:            return "AppView_ATTStatus"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .existingAuthFail(error: let error), .anonAuthFail(error: let error):
                return error.eventParameters
            case .attStatus(dict: let dict):
                return dict
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .existingAuthFail, .anonAuthFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
    
}
