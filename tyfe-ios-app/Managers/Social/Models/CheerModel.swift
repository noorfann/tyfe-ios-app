import Foundation

enum CheerKind: String, Codable, CaseIterable, Hashable, Sendable {
    case clap
    case heart
    case fire
    case star

    var displayName: String {
        switch self {
        case .clap: return "Clap"
        case .heart: return "Heart"
        case .fire: return "Fire"
        case .star: return "Star"
        }
    }

    var symbolName: String {
        switch self {
        case .clap: return "hands.clap"
        case .heart: return "heart.fill"
        case .fire: return "flame.fill"
        case .star: return "star.fill"
        }
    }
}

struct CheerModel: Identifiable, Codable, Hashable {
    let cheerId: String
    let senderId: String
    let recipientId: String
    let localDate: String
    let kind: CheerKind
    let createdAt: Date

    var id: String {
        cheerId
    }

    enum CodingKeys: String, CodingKey {
        case cheerId = "id"
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case localDate = "local_date"
        case kind
        case createdAt = "created_at"
    }
}
