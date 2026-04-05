import Foundation
import CoreGraphics

struct Photo: Codable, Identifiable, Hashable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    var filteredStoragePath: String?
    var width: Int?
    var height: Int?
    var filterApplied: Bool
    let createdAt: Date

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
    }

    var aspectRatio: CGFloat {
        guard let w = width, let h = height, h > 0 else { return 3.0 / 4.0 }
        return CGFloat(w) / CGFloat(h)
    }
}
