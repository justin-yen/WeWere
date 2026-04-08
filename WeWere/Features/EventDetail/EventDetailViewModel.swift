import Foundation
import SwiftUI

@MainActor
class EventDetailViewModel: ObservableObject {
    let eventId: UUID

    @Published var event: Event?
    @Published var members: [(EventMember, AppUser)] = []
    @Published var photoCount: Int = 0
    @Published var isLoading = true
    @Published var isHost = false
    @Published var showEndConfirmation = false
    @Published var isEnding = false
    @Published var eventWasEnded = false

    private let eventService = EventService()
    private let photoService = PhotoService()
    weak var authService: AuthService?

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func load() async {
        isLoading = true

        // Fetch everything concurrently
        async let eventFetch = eventService.fetchEvent(byId: eventId)
        async let membersFetch = eventService.fetchMembers(eventId: eventId)
        async let countFetch = photoService.getPhotoCount(eventId: eventId)

        // Collect results
        var fetchedEvent: Event?
        var fetchedMembers: [MemberWithUser] = []
        var fetchedCount: Int = 0

        do { fetchedEvent = try await eventFetch } catch { print("Event fetch: \(error)") }
        do { fetchedMembers = try await membersFetch } catch { print("Members fetch: \(error)") }
        do { fetchedCount = try await countFetch } catch { print("Count fetch: \(error)") }

        // Apply all at once
        event = fetchedEvent
        members = fetchedMembers.map { mwu in
            let user = mwu.user ?? AppUser(
                id: mwu.userId,
                authId: nil,
                firstName: "",
                lastName: "",
                displayName: "Member",
                instagramHandle: nil,
                phoneNumber: nil,
                avatarUrl: nil,
                pushToken: nil,
                createdAt: Date()
            )
            return (mwu.toEventMember, user)
        }
        photoCount = fetchedCount

        if let event = fetchedEvent, let currentUser = authService?.currentUser {
            isHost = (currentUser.id == event.hostId)
        }

        isLoading = false
    }

    func subscribeToUpdates() {
        eventService.subscribeToPhotoCount(eventId: eventId) { [weak self] count in
            Task { @MainActor in
                self?.photoCount = count
            }
        }
    }

    func subscribeToEventEnd() {
        eventService.subscribeToEventStatus(eventId: eventId) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                if status == .ended {
                    self.event?.status = .ended
                    self.eventWasEnded = true
                    NotificationCenter.default.post(name: .eventUpdated, object: nil)
                }
            }
        }
    }

    func endEvent() async {
        isEnding = true
        defer { isEnding = false }
        do {
            try await eventService.endEvent(id: eventId)
            event?.status = .ended
        } catch {
            print("Failed to end event: \(error)")
        }
    }
}
