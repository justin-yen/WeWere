import Foundation
import Supabase

@MainActor
final class PhotoService: ObservableObject {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    private let bucketName = "event-photos"

    // MARK: - Upload

    func uploadPhoto(eventId: UUID, imageData: Data) async throws -> Photo {
        guard let authUser = client.auth.currentUser else {
            throw PhotoError.notAuthenticated
        }

        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        let photoId = UUID()
        let storagePath = "\(eventId.uuidString)/originals/\(photoId.uuidString).heic"

        try await client.storage
            .from(bucketName)
            .upload(
                path: storagePath,
                file: imageData,
                options: FileOptions(contentType: "image/heic")
            )

        struct NewPhoto: Encodable {
            let id: UUID
            let eventId: UUID
            let userId: UUID
            let storagePath: String
            let filterApplied: Bool

            enum CodingKeys: String, CodingKey {
                case id
                case eventId = "event_id"
                case userId = "user_id"
                case storagePath = "storage_path"
                case filterApplied = "filter_applied"
            }
        }

        let newPhoto = NewPhoto(
            id: photoId,
            eventId: eventId,
            userId: currentUser.id,
            storagePath: storagePath,
            filterApplied: false
        )

        let photo: Photo = try await client
            .from("photos")
            .insert(newPhoto)
            .select()
            .single()
            .execute()
            .value

        // Trigger retro filter edge function directly
        Task {
            await triggerRetroFilter(photo: photo)
        }

        return photo
    }

    /// Calls the apply-retro-filter edge function for a given photo
    private func triggerRetroFilter(photo: Photo) async {
        do {
            let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/apply-retro-filter")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "record": [
                    "id": photo.id.uuidString,
                    "event_id": photo.eventId.uuidString,
                    "storage_path": photo.storagePath
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let responseText = String(data: data, encoding: .utf8) ?? ""
                print("Retro filter response (\(httpResponse.statusCode)): \(responseText)")
            }
        } catch {
            print("Failed to trigger retro filter: \(error)")
        }
    }

    // MARK: - Fetch

    func fetchPhotos(eventId: UUID) async throws -> [Photo] {
        let photos: [Photo] = try await client
            .from("photos")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .order("created_at")
            .execute()
            .value

        return photos
    }

    func getPhotoCount(eventId: UUID) async throws -> Int {
        struct IdOnly: Decodable { let id: UUID }
        let rows: [IdOnly] = try await client
            .from("photos")
            .select("id")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        return rows.count
    }

    // MARK: - URLs & Downloads

    func getFilteredPhotoURL(photo: Photo) -> URL? {
        let path = photo.filteredStoragePath ?? photo.storagePath
        return getSignedURL(path: path)
    }

    func getSignedURL(path: String) -> URL? {
        // For private buckets, use createSignedURL
        // For now, construct the URL directly using the storage API
        let baseURL = Secrets.supabaseURL
        let urlString = "\(baseURL)/storage/v1/object/authenticated/\(bucketName)/\(path)"
        return URL(string: urlString)
    }

    /// Creates a signed URL that expires after the given duration
    func createSignedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        let url = try await client.storage
            .from(bucketName)
            .createSignedURL(path: path, expiresIn: expiresIn)
        return url
    }

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
