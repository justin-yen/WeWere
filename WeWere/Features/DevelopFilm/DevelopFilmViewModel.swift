import Foundation
import SwiftUI

@MainActor
class DevelopFilmViewModel: ObservableObject {
    let eventId: UUID
    @Published var event: Event?
    @Published var photoCount: Int = 0
    @Published var isDeveloping = false
    @Published var peakTime: Date?
    @Published var errorMessage: String?

    private let eventService = EventService()
    private let photoService = PhotoService()

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func load() async {
        do {
            event = try await eventService.fetchEvent(byId: eventId)
            photoCount = try await photoService.getPhotoCount(eventId: eventId)
            await calculatePeakTime()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func calculatePeakTime() async {
        struct PhotoTimestamp: Decodable {
            let id: UUID
            let createdAt: Date
            enum CodingKeys: String, CodingKey {
                case id
                case createdAt = "created_at"
            }
        }

        do {
            let client = SupabaseManager.shared.client
            let photos: [PhotoTimestamp] = try await client
                .from("photos")
                .select("id, created_at")
                .eq("event_id", value: eventId.uuidString)
                .execute()
                .value

            guard !photos.isEmpty else { return }

            let sorted = photos.sorted { $0.createdAt < $1.createdAt }
            let windowDuration: TimeInterval = 15 * 60 // 15 minutes

            var bestCount = 0
            var bestWindowStart: Date = sorted[0].createdAt

            for (i, photo) in sorted.enumerated() {
                let windowEnd = photo.createdAt.addingTimeInterval(windowDuration)
                let count = sorted[i...].prefix(while: { $0.createdAt <= windowEnd }).count
                if count > bestCount {
                    bestCount = count
                    bestWindowStart = photo.createdAt
                }
            }

            // Midpoint of the best window
            peakTime = bestWindowStart.addingTimeInterval(windowDuration / 2)
        } catch {
            // Silently fail - peakTime stays nil
        }
    }

    func developFilm() async throws {
        isDeveloping = true
        let client = SupabaseManager.shared.client

        guard let authUser = client.auth.currentUser else {
            isDeveloping = false
            return
        }

        // Look up internal user ID from auth ID
        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        // Encodable payload for the update
        struct DevelopUpdate: Encodable {
            let hasDeveloped: Bool
            let developedAt: String

            enum CodingKeys: String, CodingKey {
                case hasDeveloped = "has_developed"
                case developedAt = "developed_at"
            }
        }

        let payload = DevelopUpdate(
            hasDeveloped: true,
            developedAt: ISO8601DateFormatter().string(from: Date())
        )

        // Update the membership record to mark as developed
        try await client
            .from("event_members")
            .update(payload)
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
    }
}
