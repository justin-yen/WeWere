import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    let id: UUID
    var authId: UUID?
    var firstName: String
    var lastName: String
    var displayName: String?
    var instagramHandle: String?
    var phoneNumber: String?
    var avatarUrl: String?
    var pushToken: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authId = "auth_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case instagramHandle = "instagram_handle"
        case phoneNumber = "phone_number"
        case avatarUrl = "avatar_url"
        case pushToken = "push_token"
        case createdAt = "created_at"
    }

    /// Display name with fallback to first + last
    var resolvedDisplayName: String {
        if let dn = displayName, !dn.isEmpty { return dn }
        return "\(firstName) \(lastName)"
    }
}
