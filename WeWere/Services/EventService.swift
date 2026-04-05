import Foundation
import Supabase
import Realtime

@MainActor
final class EventService: ObservableObject {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    private var realtimeChannels: [String: RealtimeChannelV2] = [:]

    // MARK: - Create

    func createEvent(
        name: String,
        description: String?,
        location: String?,
        startTime: Date,
        endTime: Date
    ) async throws -> Event {
        guard let authUser = client.auth.currentUser else {
            throw EventError.notAuthenticated
        }

        // Fetch current user to get their id
        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        let shareCode = generateShareCode()

        struct NewEvent: Encodable {
            let id: UUID
            let hostId: UUID
            let name: String
            let description: String?
            let location: String?
            let startTime: Date
            let endTime: Date
            let status: String
            let shareCode: String

            enum CodingKeys: String, CodingKey {
                case id
                case hostId = "host_id"
                case name
                case description
                case location
                case startTime = "start_time"
                case endTime = "end_time"
                case status
                case shareCode = "share_code"
            }
        }

        let newEvent = NewEvent(
            id: UUID(),
            hostId: currentUser.id,
            name: name,
            description: description,
            location: location,
            startTime: startTime,
            endTime: endTime,
            status: "live",
            shareCode: shareCode
        )

        let event: Event = try await client
            .from("events")
            .insert(newEvent)
            .select()
            .single()
            .execute()
            .value

        // Add host as event member
        struct NewMember: Encodable {
            let eventId: UUID
            let userId: UUID
            let role: String

            enum CodingKeys: String, CodingKey {
                case eventId = "event_id"
                case userId = "user_id"
                case role
            }
        }

        let hostMember = NewMember(
            eventId: event.id,
            userId: currentUser.id,
            role: "host"
        )

        try await client
            .from("event_members")
            .insert(hostMember)
            .execute()

        return event
    }

    // MARK: - Fetch

    func fetchMyEvents() async throws -> [Event] {
        guard let authUser = client.auth.currentUser else {
            throw EventError.notAuthenticated
        }

        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        let memberships: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("user_id", value: currentUser.id.uuidString)
            .execute()
            .value

        let eventIds = memberships.map { $0.eventId.uuidString }
        guard !eventIds.isEmpty else { return [] }

        let events: [Event] = try await client
            .from("events")
            .select()
            .in("id", values: eventIds)
            .order("created_at", ascending: false)
            .execute()
            .value

        return events
    }

    func fetchEvent(byShareCode shareCode: String) async throws -> Event? {
        let events: [Event] = try await client
            .from("events")
            .select()
            .eq("share_code", value: shareCode)
            .limit(1)
            .execute()
            .value

        return events.first
    }

    func fetchEvent(byId id: UUID) async throws -> Event {
        let event: Event = try await client
            .from("events")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value

        return event
    }

    // MARK: - Update

    func endEvent(id: UUID) async throws {
        try await client
            .from("events")
            .update(["status": "ended"])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Members

    func joinEvent(eventId: UUID, userId: UUID) async throws {
        struct NewMember: Encodable {
            let eventId: UUID
            let userId: UUID
            let role: String

            enum CodingKeys: String, CodingKey {
                case eventId = "event_id"
                case userId = "user_id"
                case role
            }
        }

        let member = NewMember(
            eventId: eventId,
            userId: userId,
            role: "attendee"
        )

        try await client
            .from("event_members")
            .insert(member)
            .execute()
    }

    func fetchMembers(eventId: UUID) async throws -> [EventMember] {
        let members: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        return members
    }

    func fetchMembersWithUsers(eventId: UUID) async throws -> [(EventMember, AppUser)] {
        struct MemberWithUser: Decodable {
            let id: UUID
            let eventId: UUID
            let userId: UUID
            let role: EventMember.MemberRole
            let hasDeveloped: Bool
            let developedAt: Date?
            let joinedAt: Date
            let users: AppUser

            enum CodingKeys: String, CodingKey {
                case id
                case eventId = "event_id"
                case userId = "user_id"
                case role
                case hasDeveloped = "has_developed"
                case developedAt = "developed_at"
                case joinedAt = "joined_at"
                case users
            }
        }

        let rows: [MemberWithUser] = try await client
            .from("event_members")
            .select("*, users(*)")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        return rows.map { row in
            let member = EventMember(
                id: row.id,
                eventId: row.eventId,
                userId: row.userId,
                role: row.role,
                hasDeveloped: row.hasDeveloped,
                developedAt: row.developedAt,
                joinedAt: row.joinedAt
            )
            return (member, row.users)
        }
    }

    func getMembership(eventId: UUID, userId: UUID) async throws -> EventMember? {
        let members: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return members.first
    }

    // MARK: - Realtime

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
                // Fetch updated count after each insert
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

    private func generateShareCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    private func getPhotoCount(eventId: UUID) async throws -> Int {
        struct IdOnly: Decodable { let id: UUID }
        let rows: [IdOnly] = try await client
            .from("photos")
            .select("id")
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        return rows.count
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
