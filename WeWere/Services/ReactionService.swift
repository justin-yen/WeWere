import Foundation
import Supabase

@MainActor
final class ReactionService: ObservableObject {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Add

    func addReaction(photoId: UUID, emoji: Reaction.ReactionEmoji) async throws {
        guard let authUser = client.auth.currentUser else {
            throw ReactionError.notAuthenticated
        }

        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        struct NewReaction: Encodable {
            let photoId: UUID
            let userId: UUID
            let emoji: String

            enum CodingKeys: String, CodingKey {
                case photoId = "photo_id"
                case userId = "user_id"
                case emoji
            }
        }

        let reaction = NewReaction(
            photoId: photoId,
            userId: currentUser.id,
            emoji: emoji.rawValue
        )

        try await client
            .from("reactions")
            .insert(reaction)
            .execute()
    }

    // MARK: - Remove

    func removeReaction(photoId: UUID, emoji: Reaction.ReactionEmoji) async throws {
        guard let authUser = client.auth.currentUser else {
            throw ReactionError.notAuthenticated
        }

        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        try await client
            .from("reactions")
            .delete()
            .eq("photo_id", value: photoId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .eq("emoji", value: emoji.rawValue)
            .execute()
    }

    // MARK: - Fetch

    func fetchReactions(photoId: UUID) async throws -> [Reaction] {
        let reactions: [Reaction] = try await client
            .from("reactions")
            .select()
            .eq("photo_id", value: photoId.uuidString)
            .execute()
            .value

        return reactions
    }

    func fetchReactionCounts(photoId: UUID) async throws -> [Reaction.ReactionEmoji: Int] {
        let reactions = try await fetchReactions(photoId: photoId)

        var counts: [Reaction.ReactionEmoji: Int] = [:]
        for reaction in reactions {
            counts[reaction.emoji, default: 0] += 1
        }

        return counts
    }

    // MARK: - Errors

    enum ReactionError: LocalizedError {
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to react."
            }
        }
    }
}
