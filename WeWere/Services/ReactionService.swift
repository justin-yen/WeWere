import Foundation

// MARK: - Backend response types

struct ReactionResponse: Decodable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }
}

struct MyReactionsResponse: Decodable {
    let emojis: [String]
}

// MARK: - Reaction Service

@MainActor
final class ReactionService {
    private let api = APIClient.shared

    func addReaction(photoId: UUID, emoji: Reaction.ReactionEmoji) async throws {
        struct AddReactionRequest: Encodable {
            let emoji: String
        }

        let _: ReactionResponse = try await api.post(
            "/photos/\(photoId.uuidString)/reactions",
            body: AddReactionRequest(emoji: emoji.rawValue)
        )
    }

    func removeReaction(photoId: UUID, emoji: Reaction.ReactionEmoji) async throws {
        let _: EmptyResponse = try await api.delete(
            "/photos/\(photoId.uuidString)/reactions/\(emoji.rawValue)"
        )
    }

    func fetchMyReactions(photoId: UUID) async throws -> Set<Reaction.ReactionEmoji> {
        let response: MyReactionsResponse = try await api.get(
            "/photos/\(photoId.uuidString)/reactions/me"
        )

        return Set(response.emojis.compactMap { Reaction.ReactionEmoji(rawValue: $0) })
    }
}
