import SwiftUI
import Photos

@MainActor
class PhotoDetailViewModel: ObservableObject {
    let photoId: UUID
    let eventId: UUID?

    @Published var photo: Photo?
    @Published var photographer: AppUser?
    @Published var myReactions: Set<Reaction.ReactionEmoji> = []
    @Published var reactionCounts: [Reaction.ReactionEmoji: Int] = [:]
    @Published var reactorNames: [Reaction.ReactionEmoji: [String]] = [:]
    @Published var comments: [PhotoComment] = []

    private let photoService = PhotoService()
    private let reactionService = ReactionService()
    private let api = APIClient.shared

    init(photoId: UUID, eventId: UUID? = nil) {
        self.photoId = photoId
        self.eventId = eventId
    }

    /// Set the photo directly if already available (from album cache)
    func setPhoto(_ photo: Photo) {
        self.photo = photo
    }

    func load() async {
        print("DEBUG load: photo=\(photo?.id.uuidString ?? "nil"), photoId=\(photoId)")

        // If photo wasn't pre-set, try to find it from the album cache
        if photo == nil {
            // Search all cached album photos
            for (_, cachedPhotos) in AlbumViewModel.allCachedPhotos {
                if let found = cachedPhotos.first(where: { $0.id == photoId }) {
                    self.photo = found
                    break
                }
            }
        }

        // If still nil, fetch from Supabase
        if photo == nil {
            do {
                let client = SupabaseManager.shared.client
                let photos: [Photo] = try await client
                    .from("photos")
                    .select()
                    .eq("id", value: photoId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                self.photo = photos.first
            } catch {
                print("Failed to load photo: \(error)")
            }
        }

        print("DEBUG load after fetch attempts: photo=\(photo?.id.uuidString ?? "STILL NIL")")

        // Load photographer
        if let photo = photo, photographer == nil {
            do {
                let client = SupabaseManager.shared.client
                let users: [AppUser] = try await client
                    .from("users")
                    .select()
                    .eq("id", value: photo.userId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                self.photographer = users.first
            } catch {
                print("Failed to load photographer: \(error)")
            }
        }

        await loadReactions()
        await loadComments()
    }

    private func loadReactions() async {
        // Load which emojis the current user has reacted with
        do {
            myReactions = try await reactionService.fetchMyReactions(photoId: photoId)
        } catch {
            print("Failed to load my reactions: \(error)")
        }

        // Load all reactions with user info via backend
        do {
            let reactions: [BackendReaction] = try await api.get(
                "/photos/\(photoId.uuidString)/reactions"
            )

            var counts: [Reaction.ReactionEmoji: Int] = [:]
            var names: [Reaction.ReactionEmoji: [String]] = [:]

            for r in reactions {
                guard let emoji = Reaction.ReactionEmoji(rawValue: r.emoji) else { continue }
                counts[emoji, default: 0] += 1
                let name = r.user?.resolvedName ?? "Unknown"
                names[emoji, default: []].append(name)
            }

            reactionCounts = counts
            reactorNames = names
        } catch {
            print("Failed to load reaction details: \(error)")
        }
    }

    // Track in-flight toggles to prevent double-taps
    private var togglingEmojis: Set<Reaction.ReactionEmoji> = []

    func toggleReaction(_ emoji: Reaction.ReactionEmoji) async {
        // Ignore if already toggling this emoji
        guard !togglingEmojis.contains(emoji) else { return }
        togglingEmojis.insert(emoji)
        defer { togglingEmojis.remove(emoji) }

        let wasSelected = myReactions.contains(emoji)
        let myName = APIClient.shared.currentUserName ?? "You"

        // Optimistic update
        if wasSelected {
            myReactions.remove(emoji)
            reactionCounts[emoji, default: 1] -= 1
            if reactionCounts[emoji, default: 0] <= 0 { reactionCounts.removeValue(forKey: emoji) }
            reactorNames[emoji]?.removeAll { $0 == myName }
            if reactorNames[emoji]?.isEmpty == true { reactorNames.removeValue(forKey: emoji) }
        } else {
            myReactions.insert(emoji)
            reactionCounts[emoji, default: 0] += 1
            if reactorNames[emoji]?.contains(myName) != true {
                reactorNames[emoji, default: []].append(myName)
            }
        }

        // Persist to backend -- no re-fetch, optimistic state is the source of truth
        do {
            if wasSelected {
                try await reactionService.removeReaction(photoId: photoId, emoji: emoji)
            } else {
                try await reactionService.addReaction(photoId: photoId, emoji: emoji)
            }
        } catch {
            // Revert on failure
            if wasSelected {
                myReactions.insert(emoji)
                reactionCounts[emoji, default: 0] += 1
                reactorNames[emoji, default: []].append(myName)
            } else {
                myReactions.remove(emoji)
                reactionCounts[emoji, default: 1] -= 1
                if reactionCounts[emoji, default: 0] <= 0 { reactionCounts.removeValue(forKey: emoji) }
                reactorNames[emoji]?.removeAll { $0 == myName }
            }
            print("Failed to toggle reaction: \(error)")
        }
    }

    // MARK: - Comments

    private var resolvedEventId: UUID? {
        eventId ?? photo?.eventId
    }

    func loadComments() async {
        guard let eid = resolvedEventId else {
            print("DEBUG comments: no eventId available")
            return
        }
        do {
            let result: [PhotoComment] = try await api.get(
                "/events/\(eid)/photos/\(photoId)/comments"
            )
            comments = result
        } catch {
            print("Failed to load comments: \(error)")
        }
    }

    func addComment(text: String) async {
        guard let eid = resolvedEventId else {
            print("DEBUG addComment: no eventId available")
            return
        }
        let body = ["text": text]
        do {
            let _: PhotoComment = try await api.post(
                "/events/\(eid)/photos/\(photoId)/comments",
                body: body
            )
            await loadComments()
        } catch {
            print("Failed to add comment: \(error)")
        }
    }

    var signedURL: URL?

    func saveToPhotoLibrary() async throws {
        guard let url = signedURL else {
            print("No signed URL for saving")
            return
        }

        let (data, _) = try await URLSession.shared.data(from: url)
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

// MARK: - Backend reaction response

private struct BackendReaction: Decodable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date?
    let user: BackendReactionUser?

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
        case user
    }
}

private struct BackendReactionUser: Decodable {
    let id: UUID?
    let firstName: String?
    let lastName: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
    }

    var resolvedName: String {
        if let dn = displayName, !dn.isEmpty { return dn }
        let first = firstName ?? ""
        let last = lastName ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Unknown" : full
    }
}

// MARK: - Comment model

struct PhotoComment: Decodable, Identifiable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let text: String
    let createdAt: Date
    let user: CommentUser?

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case userId = "user_id"
        case text
        case createdAt = "created_at"
        case user
    }

    var userName: String {
        guard let u = user else { return "Unknown" }
        let full = "\(u.firstName) \(u.lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Unknown" : full
    }
}

struct CommentUser: Decodable {
    let id: UUID
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

