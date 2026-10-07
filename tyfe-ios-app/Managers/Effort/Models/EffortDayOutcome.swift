import Foundation

enum EffortDayOutcome: String, Codable, Hashable, Sendable {
    case pending, successful, neutral, missed
}
