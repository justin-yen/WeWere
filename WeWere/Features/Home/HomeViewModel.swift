import Foundation
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var memberships: [UUID: EventMember] = [:]
    @Published var photoCounts: [UUID: Int] = [:]
    @Published var memberCounts: [UUID: Int] = [:]
    @Published var isLoading = true

    private let eventService = EventService()
    private let photoService = PhotoService()
    private var isSubscribed = false

    var liveEvents: [Event] {
        events.filter { $0.isLive }
    }

    var readyToDevelop: [Event] {
        events.filter { $0.isEnded && !(memberships[$0.id]?.hasDeveloped ?? false) }
    }

    var developedEvents: [Event] {
        events.filter { $0.isEnded && (memberships[$0.id]?.hasDeveloped ?? false) }
    }

    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let client = SupabaseManager.shared.client
            guard let authUser = client.auth.currentUser else { return }

            let currentUser: AppUser = try await client
                .from("users")
                .select()
                .eq("auth_id", value: authUser.id.uuidString)
                .single()
                .execute()
                .value

            let fetchedEvents = try await eventService.fetchMyEvents()
            events = fetchedEvents

            for event in fetchedEvents {
                let members = try await eventService.fetchMembers(eventId: event.id)
                memberCounts[event.id] = members.count

                if let membership = members.first(where: { $0.userId == currentUser.id }) {
                    memberships[event.id] = membership
                }

                do {
                    let count = try await photoService.getPhotoCount(eventId: event.id)
                    photoCounts[event.id] = count
                } catch {
                    photoCounts[event.id] = 0
                }
            }

            // Subscribe to realtime updates for live events
            if !isSubscribed {
                subscribeToLiveUpdates()
            }
        } catch is CancellationError {
            // ignored
        } catch {
            print("Failed to load events: \(error.localizedDescription)")
        }
    }

    private func subscribeToLiveUpdates() {
        isSubscribed = true
        for event in liveEvents {
            // Photo count updates
            eventService.subscribeToPhotoCount(eventId: event.id) { [weak self] count in
                Task { @MainActor in
                    self?.photoCounts[event.id] = count
                }
            }
        }
    }
}
