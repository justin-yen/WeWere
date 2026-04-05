import Foundation

struct Event: Codable, Identifiable, Hashable {
    let id: UUID
    let hostId: UUID
    var name: String
    var description: String?
    var location: String?
    var coverImageUrl: String?
    let startTime: Date
    let endTime: Date
    var status: EventStatus
    let shareCode: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case name
        case description
        case location
        case coverImageUrl = "cover_image_url"
        case startTime = "start_time"
        case endTime = "end_time"
        case status
        case shareCode = "share_code"
        case createdAt = "created_at"
    }

    enum EventStatus: String, Codable, Hashable {
        case live, ended
    }

    var isLive: Bool { status == .live }
    var isEnded: Bool { status == .ended }
    var hasStarted: Bool { Date() >= startTime }

    var timeRemaining: TimeInterval? {
        guard isLive else { return nil }
        return endTime.timeIntervalSince(Date())
    }

    var shareURL: URL? {
        URL(string: "https://wewere.app/event/\(shareCode)")
    }
}
