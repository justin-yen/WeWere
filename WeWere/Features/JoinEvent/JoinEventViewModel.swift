import Foundation

@MainActor
class JoinEventViewModel: ObservableObject {
    let shareCode: String

    @Published var event: Event?
    @Published var displayName: String = ""
    @Published var isLoading = true
    @Published var isJoining = false
    @Published var error: String?

    private let eventService = EventService()
    private let authService = AuthService()

    init(shareCode: String) {
        self.shareCode = shareCode
    }

    func loadEvent() async {
        isLoading = true
        event = try? await eventService.fetchEvent(byShareCode: shareCode)
        isLoading = false
    }

    func joinEvent() async throws {
        guard let event = event,
              !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isJoining = true
        defer { isJoining = false }

        // Update display name
        try await authService.updateDisplayName(displayName)

        // Join as attendee
        let client = SupabaseManager.shared.client
        let userId = try await client.auth.session.user.id

        let currentUser: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: userId.uuidString)
            .single()
            .execute()
            .value

        try await eventService.joinEvent(eventId: event.id, userId: currentUser.id)
    }
}
