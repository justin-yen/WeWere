import Foundation

struct EventMember: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let role: MemberRole
    var hasDeveloped: Bool
    var developedAt: Date?
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case role
        case hasDeveloped = "has_developed"
        case developedAt = "developed_at"
        case joinedAt = "joined_at"
    }

    enum MemberRole: String, Codable, Hashable {
        case host, attendee
    }

    var isHost: Bool { role == .host }
}
