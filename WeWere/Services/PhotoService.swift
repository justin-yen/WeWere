import Foundation
import Supabase

// MARK: - Backend Response Types

/// Photo response from backend includes signed URLs
struct PhotoResponse: Decodable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    var filteredStoragePath: String?
    var width: Int?
    var height: Int?
    var filterApplied: Bool?
    let createdAt: Date
    var signedUrl: String?
    var user: PhotoUser?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case storagePath = "storage_path"
        case filteredStoragePath = "filtered_storage_path"
        case width
        case height
        case filterApplied = "filter_applied"
        case createdAt = "created_at"
        case signedUrl = "signed_url"
        case user
    }
}

struct PhotoUser: Decodable, Hashable {
    let id: UUID
    var firstName: String?
    var lastName: String?
    var displayName: String?
    var instagramHandle: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case instagramHandle = "instagram_handle"
    }

    var resolvedDisplayName: String {
        if let dn = displayName, !dn.isEmpty { return dn }
        let first = firstName ?? ""
        let last = lastName ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Unknown" : full
    }
}

extension PhotoResponse {
    var toPhoto: Photo {
        Photo(
            id: id,
            eventId: eventId,
            userId: userId,
            storagePath: storagePath,
            filteredStoragePath: filteredStoragePath,
            width: width,
            height: height,
            filterApplied: filterApplied ?? false,
            createdAt: createdAt
        )
    }
}

struct PhotoCountResponse: Decodable {
    let count: Int
}

// MARK: - Photo Service

@MainActor
final class PhotoService: ObservableObject {
    private let api = APIClient.shared

    // Keep Supabase client for downloading photos (storage) if needed
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private let bucketName = "event-photos"

    // MARK: - Upload

    func uploadPhoto(eventId: UUID, imageData: Data) async throws -> Photo {
        let response: PhotoResponse = try await api.upload(
            path: "/events/\(eventId.uuidString)/photos",
            fileData: imageData,
            fileName: "\(UUID().uuidString).heic",
            mimeType: "image/heic"
        )

        return response.toPhoto
    }

    // MARK: - Fetch

    func fetchPhotos(eventId: UUID) async throws -> [PhotoResponse] {
        let photos: [PhotoResponse] = try await api.get("/events/\(eventId.uuidString)/photos")
        return photos
    }

    func getPhotoCount(eventId: UUID) async throws -> Int {
        let response: PhotoCountResponse = try await api.get("/events/\(eventId.uuidString)/photos/count")
        return response.count
    }

    // MARK: - URLs

    /// Get URL for a photo -- backend provides signed URLs in photo list responses
    func getFilteredPhotoURL(photo: Photo) -> URL? {
        // This is a fallback for when we don't have a signed URL from the backend
        let path = photo.filteredStoragePath ?? photo.storagePath
        let baseURL = Secrets.supabaseURL
        let urlString = "\(baseURL)/storage/v1/object/authenticated/\(bucketName)/\(path)"
        return URL(string: urlString)
    }

    /// Downloads photo data via Supabase storage (for saving to library)
    func downloadPhotoData(photo: Photo) async throws -> Data {
        let data = try await client.storage
            .from(bucketName)
            .download(path: photo.storagePath)

        return data
    }

    // MARK: - Errors

    enum PhotoError: LocalizedError {
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to upload photos."
            }
        }
    }
}
