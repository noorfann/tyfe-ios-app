import Foundation

enum CircleFocusStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case focusing
    case available

    var displayName: String {
        switch self {
        case .focusing: return "Focusing"
        case .available: return "Available"
        }
    }

    var symbolName: String {
        switch self {
        case .focusing: return "timer"
        case .available: return "circle.dashed"
        }
    }
}

struct CircleFocusStatusEntry: Identifiable, Hashable, Sendable {
    let userId: String
    let status: CircleFocusStatus

    var id: String {
        userId
    }
}

struct CirclePresencePayload: Codable, Hashable, Sendable {
    let userId: String
    let status: CircleFocusStatus

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case status
    }
}
