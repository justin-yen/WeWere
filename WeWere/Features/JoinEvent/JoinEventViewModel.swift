import Foundation

@MainActor
class JoinEventViewModel: ObservableObject {
    let shareCode: String

    @Published var event: Event?
    @Published var isLoading = true
    @Published var isJoining = false
    @Published var hasJoined = false
    @Published var error: String?

    private let eventService = EventService()

    init(shareCode: String) {
        self.shareCode = shareCode
    }

    func loadEvent() async {
        isLoading = true
        do {
            event = try await eventService.fetchEvent(byShareCode: shareCode)
        } catch {
            self.error = "Event not found"
            print("Failed to load event by share code: \(error)")
        }
        isLoading = false
    }

    func joinEvent() async {
        guard let event = event else { return }

        isJoining = true
        defer { isJoining = false }

        do {
            try await eventService.joinEvent(eventId: event.id, userId: UUID())
            hasJoined = true
            NotificationCenter.default.post(name: .eventCreated, object: nil)
        } catch {
            self.error = "Failed to join event"
            print("Join event error: \(error)")
        }
    }
}
