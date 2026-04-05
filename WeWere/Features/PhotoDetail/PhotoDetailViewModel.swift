import SwiftUI
import Photos

@MainActor
class PhotoDetailViewModel: ObservableObject {
    let photoId: UUID

    @Published var photo: Photo?
    @Published var photographer: AppUser?
    @Published var reactions: [Reaction] = []
    @Published var reactionCounts: [Reaction.ReactionEmoji: Int] = [:]
    @Published var myReactions: Set<Reaction.ReactionEmoji> = []

    private let photoService = PhotoService()
    private let reactionService = ReactionService()

    init(photoId: UUID) {
        self.photoId = photoId
    }

    func load() async {
        // Fetch photo
        do {
            let client = SupabaseManager.shared.client
            let photos: [Photo] = try await client
                .from("photos")
                .select()
                .eq("id", value: photoId.uuidString)
                .limit(1)
                .execute()
                .value

            guard let photo = photos.first else { return }
            self.photo = photo

            // Fetch photographer
            let users: [AppUser] = try await client
                .from("users")
                .select()
                .eq("id", value: photo.userId.uuidString)
                .limit(1)
                .execute()
                .value
            self.photographer = users.first

            // Fetch reactions
            await loadReactions()
        } catch {
            // Silently handle errors for now
        }
    }

    private func loadReactions() async {
        do {
            reactions = try await reactionService.fetchReactions(photoId: photoId)
            reactionCounts = try await reactionService.fetchReactionCounts(photoId: photoId)

            // Determine which reactions belong to the current user
            if let authUser = SupabaseManager.shared.client.auth.currentUser {
                let client = SupabaseManager.shared.client
                let currentUsers: [AppUser] = try await client
                    .from("users")
                    .select()
                    .eq("auth_id", value: authUser.id.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if let currentUser = currentUsers.first {
                    myReactions = Set(
                        reactions
                            .filter { $0.userId == currentUser.id }
                            .map { $0.emoji }
                    )
                }
            }
        } catch {
            // Silently handle errors
        }
    }

    func toggleReaction(_ emoji: Reaction.ReactionEmoji) async {
        do {
            if myReactions.contains(emoji) {
                try await reactionService.removeReaction(photoId: photoId, emoji: emoji)
                myReactions.remove(emoji)
                reactionCounts[emoji, default: 1] -= 1
            } else {
                try await reactionService.addReaction(photoId: photoId, emoji: emoji)
                myReactions.insert(emoji)
                reactionCounts[emoji, default: 0] += 1
            }
        } catch {
            // Revert optimistic update by reloading
            await loadReactions()
        }
    }

    func saveToPhotoLibrary() async throws {
        guard let photo = photo else { return }

        let data: Data
        if let filteredPath = photo.filteredStoragePath {
            data = try await SupabaseManager.shared.client.storage
                .from("event-photos")
                .download(path: filteredPath)
        } else {
            data = try await photoService.downloadPhotoData(photo: photo)
        }

        guard let image = UIImage(data: data) else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
