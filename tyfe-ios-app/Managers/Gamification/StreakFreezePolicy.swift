import Foundation

enum StreakFreezePolicy {
    static let milestoneInterval = 7
    static let maximumAvailableFreezes = 3
    static let guidance = "Earn 1 every 7 streak days. Hold up to 3. Applied automatically."

    static func freezeId(streakStart: Date, milestone: Int) -> String {
        let startMilliseconds = Int(streakStart.timeIntervalSince1970 * 1_000)
        return "focus-\(startMilliseconds)-day-\(milestone)"
    }
}
