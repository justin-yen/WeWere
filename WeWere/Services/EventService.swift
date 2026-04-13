import Foundation
import Supabase
import Realtime

// MARK: - Backend Request/Response Types

struct CreateEventRequest: Encodable {
    let name: String
    let description: String?
    let location: String?
    let locationName: String?
    let locationAddress: String?
    let locationLat: Double?
    let locationLng: Double?
    let startTime: Date
    let endTime: Date
    let coverPhotoUrl: String?
    let coverPhotoAttribution: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case location
        case locationName = "location_name"
        case locationAddress = "location_address"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case startTime = "start_time"
        case endTime = "end_time"
        case coverPhotoUrl = "cover_photo_url"
        case coverPhotoAttribution = "cover_photo_attribution"
    }
}

/// The backend returns events with extra fields like photo_count and member_count
struct EventWithCounts: Decodable, Identifiable {
    let id: UUID
    let hostId: UUID
    var name: String
    var description: String?
    var location: String?
    var locationName: String?
    var locationAddress: String?
    var locationLat: Double?
    var locationLng: Double?
    var coverPhotoUrl: String?
    var coverPhotoAttribution: String?
    let startTime: Date
    let endTime: Date
    var status: Event.EventStatus
    let shareCode: String
    let createdAt: Date
    var photoCount: Int?
    var memberCount: Int?
    var membership: MembershipInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case name
        case description
        case location
        case locationName = "location_name"
        case locationAddress = "location_address"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case coverPhotoUrl = "cover_photo_url"
        case coverPhotoAttribution = "cover_photo_attribution"
        case startTime = "start_time"
        case endTime = "end_time"
        case status
        case shareCode = "share_code"
        case createdAt = "created_at"
        case photoCount = "photo_count"
        case memberCount = "member_count"
        case membership
    }

    var toEvent: Event {
        Event(
            id: id,
            hostId: hostId,
            name: name,
            description: description,
            location: location,
            locationName: locationName,
            locationAddress: locationAddress,
            locationLat: locationLat,
            locationLng: locationLng,
            coverPhotoUrl: coverPhotoUrl,
            coverPhotoAttribution: coverPhotoAttribution,
            startTime: startTime,
            endTime: endTime,
            status: status,
            shareCode: shareCode,
            createdAt: createdAt
        )
    }
}

struct MembershipInfo: Decodable {
    let hasDeveloped: Bool
    let developedAt: Date?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case hasDeveloped = "has_developed"
        case developedAt = "developed_at"
        case role
    }
}

struct MemberWithUser: Decodable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let role: EventMember.MemberRole
    let hasDeveloped: Bool
    let developedAt: Date?
    let joinedAt: Date
    let user: AppUser?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case role
        case hasDeveloped = "has_developed"
        case developedAt = "developed_at"
        case joinedAt = "joined_at"
        case user
    }

    var toEventMember: EventMember {
        EventMember(
            id: id,
            eventId: eventId,
            userId: userId,
            role: role,
            hasDeveloped: hasDeveloped,
            developedAt: developedAt,
            joinedAt: joinedAt
        )
    }
}

struct JoinEventRequest: Encodable {}

// MARK: - Event Service

@MainActor
final class EventService: ObservableObject {
    private let api = APIClient.shared

    // Keep Supabase client for realtime subscriptions only
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var realtimeChannels: [String: RealtimeChannelV2] = [:]

    // MARK: - Create

    func createEvent(
        name: String,
        description: String?,
        location: String?,
        locationName: String?,
        locationAddress: String?,
        locationLat: Double?,
        locationLng: Double?,
        startTime: Date,
        endTime: Date,
        coverPhotoUrl: String? = nil,
        coverPhotoAttribution: String? = nil
    ) async throws -> Event {
        let request = CreateEventRequest(
            name: name,
            description: description,
            location: location,
            locationName: locationName,
            locationAddress: locationAddress,
            locationLat: locationLat,
            locationLng: locationLng,
            startTime: startTime,
            endTime: endTime,
            coverPhotoUrl: coverPhotoUrl,
            coverPhotoAttribution: coverPhotoAttribution
        )

        let event: Event = try await api.post("/events", body: request)
        return event
    }

    // MARK: - Fetch

    func fetchMyEvents() async throws -> [EventWithCounts] {
        let events: [EventWithCounts] = try await api.get("/events")
        return events
    }

    func fetchEvent(byShareCode shareCode: String) async throws -> Event? {
        let event: Event = try await api.get("/events/join/\(shareCode)", requiresAuth: false)
        return event
    }

    func fetchEvent(byId id: UUID) async throws -> Event {
        let event: Event = try await api.get("/events/\(id.uuidString)")
        return event
    }

    // MARK: - Update

    func endEvent(id: UUID) async throws {
        let _: EmptyResponse = try await api.post("/events/\(id.uuidString)/end", body: EmptyRequest())
    }

    // MARK: - Members

    func joinEvent(eventId: UUID, userId: UUID) async throws {
        let _: EmptyResponse = try await api.post("/events/\(eventId.uuidString)/join", body: JoinEventRequest())
    }

    func fetchMembers(eventId: UUID) async throws -> [MemberWithUser] {
        let members: [MemberWithUser] = try await api.get("/events/\(eventId.uuidString)/members")
        return members
    }

    func getMembership(eventId: UUID, userId: UUID) async throws -> EventMember? {
        // Fetch all members and find the matching one
        let members = try await fetchMembers(eventId: eventId)
        return members.first(where: { $0.userId == userId })?.toEventMember
    }

    // MARK: - Realtime (still uses Supabase directly)

    func subscribeToPhotoCount(eventId: UUID, onUpdate: @escaping (Int) -> Void) {
        let channelKey = "photos-\(eventId.uuidString)"
        let channel = client.channel(channelKey)

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "photos",
            filter: "event_id=eq.\(eventId.uuidString)"
        )

        Task {
            await channel.subscribe()

            for await _ in changes {
                // Fetch updated count via API
                if let count = try? await self.getPhotoCount(eventId: eventId) {
                    onUpdate(count)
                }
            }
        }

        realtimeChannels[channelKey] = channel
    }

    func subscribeToEventStatus(eventId: UUID, onStatusChange: @escaping (Event.EventStatus) -> Void) {
        let channelKey = "event-status-\(eventId.uuidString)"
        let channel = client.channel(channelKey)

        let changes = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "events",
            filter: "id=eq.\(eventId.uuidString)"
        )

        Task {
            await channel.subscribe()

            for await action in changes {
                if let statusString = action.record["status"]?.stringValue,
                   let status = Event.EventStatus(rawValue: statusString) {
                    onStatusChange(status)
                }
            }
        }

        realtimeChannels[channelKey] = channel
    }

    // MARK: - Helpers

    private func getPhotoCount(eventId: UUID) async throws -> Int {
        let response: PhotoCountResponse = try await api.get("/events/\(eventId.uuidString)/photos/count")
        return response.count
    }

    // MARK: - Errors

    enum EventError: LocalizedError {
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to perform this action."
            }
        }
    }
}

private struct EmptyRequest: Encodable {}
