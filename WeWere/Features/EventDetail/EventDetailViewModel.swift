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

    // MARK: - Static cache (survives view rebuilds and navigation)

    private static var cachedEvents: [UUID: Event] = [:]
    private static var cachedMembers: [UUID: [(EventMember, AppUser)]] = [:]
    private static var cachedPhotoCounts: [UUID: Int] = [:]

    init(eventId: UUID) {
        self.eventId = eventId

        // Restore from cache immediately so the view renders without a spinner
        if let cachedEvent = Self.cachedEvents[eventId] {
            self.event = cachedEvent
            self.members = Self.cachedMembers[eventId] ?? []
            self.photoCount = Self.cachedPhotoCounts[eventId] ?? 0
            self.isLoading = false
        }
    }

    func load() async {
        // If we have cached data, revalidate in the background without a spinner
        let hasCached = event != nil
        if !hasCached {
            isLoading = true
        }

        // Fetch everything concurrently
        async let eventFetch = eventService.fetchEvent(byId: eventId)
        async let membersFetch = eventService.fetchMembers(eventId: eventId)
        async let countFetch = photoService.getPhotoCount(eventId: eventId)

        var fetchedEvent: Event?
        var fetchedMembers: [MemberWithUser] = []
        var fetchedCount: Int = 0

        do { fetchedEvent = try await eventFetch } catch { print("Event fetch: \(error)") }
        do { fetchedMembers = try await membersFetch } catch { print("Members fetch: \(error)") }
        do { fetchedCount = try await countFetch } catch { print("Count fetch: \(error)") }

        // Apply results
        if let fetched = fetchedEvent {
            event = fetched
            Self.cachedEvents[eventId] = fetched
        }

        let mappedMembers: [(EventMember, AppUser)] = fetchedMembers.map { mwu in
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
        if !mappedMembers.isEmpty || fetchedMembers.isEmpty == false {
            members = mappedMembers
            Self.cachedMembers[eventId] = mappedMembers
        }

        photoCount = fetchedCount
        Self.cachedPhotoCounts[eventId] = fetchedCount

        if let event = event, let currentUser = authService?.currentUser {
            isHost = (currentUser.id == event.hostId)
        }

        isLoading = false
    }

    func subscribeToUpdates() {
        eventService.subscribeToPhotoCount(eventId: eventId) { [weak self] count in
            Task { @MainActor in
                guard let self else { return }
                self.photoCount = count
                Self.cachedPhotoCounts[self.eventId] = count
            }
        }
    }

    func subscribeToEventEnd() {
        eventService.subscribeToEventStatus(eventId: eventId) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                if status == .ended {
                    self.event?.status = .ended
                    if let updated = self.event {
                        Self.cachedEvents[self.eventId] = updated
                    }
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
            if let updated = event {
                Self.cachedEvents[eventId] = updated
            }
            eventWasEnded = true
            NotificationCenter.default.post(name: .eventUpdated, object: nil)
        } catch {
            print("Failed to end event: \(error)")
        }
    }

    /// Invalidate the cache for this event (use when the event may have changed significantly)
    static func invalidateCache(for eventId: UUID) {
        cachedEvents.removeValue(forKey: eventId)
        cachedMembers.removeValue(forKey: eventId)
        cachedPhotoCounts.removeValue(forKey: eventId)
    }
}
