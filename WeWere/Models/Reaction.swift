import Foundation

struct Reaction: Codable, Identifiable, Hashable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let emoji: ReactionEmoji
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }

    enum ReactionEmoji: String, Codable, CaseIterable, Hashable {
        case fire, heart, laugh, wow, cry

        var display: String {
            switch self {
            case .fire: return "\u{1F525}"
            case .heart: return "\u{2764}\u{FE0F}"
            case .laugh: return "\u{1F602}"
            case .wow: return "\u{1F62E}"
            case .cry: return "\u{1F622}"
            }
        }
    }
}
