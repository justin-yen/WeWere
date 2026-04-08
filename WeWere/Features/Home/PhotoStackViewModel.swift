import Foundation

struct StackPhoto: Identifiable {
    let id: UUID
    let photoId: UUID
    let eventId: UUID
    let url: URL
    let eventName: String
    let photographerName: String
    let date: Date
}

/// Response from GET /feed/random-photos
private struct FeedPhoto: Decodable {
    let id: UUID
    let photoId: UUID
    let eventId: UUID
    let eventName: String
    let photographerName: String
    let signedUrl: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case eventId = "event_id"
        case eventName = "event_name"
        case photographerName = "photographer_name"
        case signedUrl = "signed_url"
        case createdAt = "created_at"
    }
}

@MainActor
class PhotoStackViewModel: ObservableObject {
    @Published var stackPhotos: [StackPhoto] = []
    @Published var isLoading = false

    private let api = APIClient.shared
    private static var cachedPhotos: [StackPhoto]?

    func loadPhotos(developedEvents: [Event]) async {
        // Return cached results if available
        if let cached = Self.cachedPhotos, !cached.isEmpty {
            stackPhotos = cached
            return
        }

        guard !developedEvents.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Single API call returns random photos with signed URLs
            let feedPhotos: [FeedPhoto] = try await api.get("/feed/random-photos?count=8")

            let photos = feedPhotos.compactMap { fp -> StackPhoto? in
                guard let url = URL(string: fp.signedUrl), !fp.signedUrl.isEmpty else { return nil }
                return StackPhoto(
                    id: UUID(),
                    photoId: fp.photoId,
                    eventId: fp.eventId,
                    url: url,
                    eventName: fp.eventName,
                    photographerName: fp.photographerName,
                    date: fp.createdAt
                )
            }

            Self.cachedPhotos = photos
            stackPhotos = photos
        } catch {
            print("Failed to load photo stack: \(error)")
        }
    }

    func invalidateCache() {
        Self.cachedPhotos = nil
    }
}
