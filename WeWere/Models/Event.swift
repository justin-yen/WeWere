import Foundation

struct Event: Codable, Identifiable, Hashable {
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
    var status: EventStatus
    let shareCode: String
    let createdAt: Date

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
        URL(string: "wewere://event/\(shareCode)")
    }

    /// Text to share with the link
    var shareText: String {
        "Join my event \"\(name)\" on WeWere! \(shareURL?.absoluteString ?? "")"
    }
}
