import Foundation

struct FocusCompletionResult: Equatable, Codable {
    let focusSessionId: String
    let rewardCreditsAwarded: Int
    let xpAwarded: Int
    let rewardCreditBalance: Int
    let progression: ProgressionSnapshotModel
}

struct FocusSessionRefresh: Equatable {
    let session: FocusSessionModel
    let remainingFocusSeconds: Int
    let remainingPauseSeconds: Int
    let completion: FocusCompletionResult?
}

enum FocusManagerError: Error, Equatable {
    case sessionNotFound
    case invalidState
    case pauseAlreadyUsed
    case activeSessionExists
    case persistenceFailed
}
