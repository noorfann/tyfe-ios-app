#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct FocusLiveActivityAttributes: ActivityAttributes {
    let focusSessionId: String
    let activityTitle: String

    enum Phase: String, Codable, Hashable {
        case running
        case completed
        case abandoned
    }

    struct ContentState: Codable, Hashable {
        let phase: Phase
        let startedAt: Date
        let endsAt: Date
    }
}
#endif
