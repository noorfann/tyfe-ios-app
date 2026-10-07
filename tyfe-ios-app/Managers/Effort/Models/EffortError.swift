import Foundation

enum EffortError: LocalizedError, Equatable, Sendable {
    case invalidEntry, missingEntry, unavailableDay, migrationRequired

    var errorDescription: String? {
        switch self {
        case .invalidEntry: return "Enter a name and choose a valid Space and schedule."
        case .missingEntry: return "This entry is no longer available."
        case .unavailableDay: return "Only today's scheduled Habits can be changed."
        case .migrationRequired: return "Your saved work could not be prepared. Please try again."
        }
    }
}
