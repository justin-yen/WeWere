import Foundation
import SwiftUI

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
        case heart, fire, sparkles, openMouth, holdingBackTears

        var display: String {
            switch self {
            case .heart: return "\u{2764}\u{FE0F}"
            case .fire: return "\u{1F525}"
            case .sparkles: return "\u{2728}"
            case .openMouth: return "\u{1F62E}"
            case .holdingBackTears: return "\u{1F979}"
            }
        }

        var tintColor: Color {
            switch self {
            case .heart: return Color(hex: "E85D75")
            case .fire: return Color(hex: "E8803A")
            case .sparkles: return Color(hex: "D4A84B")
            case .openMouth: return Color(hex: "C49A6C")
            case .holdingBackTears: return Color(hex: "6BA3A0")
            }
        }
    }
}
