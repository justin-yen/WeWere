import Foundation
import SwiftUI

/// Shared across tabs so events are fetched once and both Home and Events tabs read from the same data.
@MainActor
class SharedEventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var memberships: [UUID: EventMember] = [:]
    @Published var photoCounts: [UUID: Int] = [:]
    @Published var memberCounts: [UUID: Int] = [:]
    @Published var isLoading = true

    private let eventService = EventService()
    private var hasFetched = false

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
            let eventsWithCounts = try await eventService.fetchMyEvents()

            events = eventsWithCounts.map { $0.toEvent }

            for ewc in eventsWithCounts {
                photoCounts[ewc.id] = ewc.photoCount ?? 0
                memberCounts[ewc.id] = ewc.memberCount ?? 0

                if let membership = ewc.membership {
                    let role: EventMember.MemberRole = membership.role == "host" ? .host : .attendee
                    let member = EventMember(
                        id: UUID(),
                        eventId: ewc.id,
                        userId: UUID(),
                        role: role,
                        hasDeveloped: membership.hasDeveloped,
                        developedAt: membership.developedAt,
                        joinedAt: ewc.createdAt
                    )
                    memberships[ewc.id] = member
                }
            }

            hasFetched = true
        } catch is CancellationError {
            // ignored
        } catch {
            print("Failed to load events: \(error.localizedDescription)")
        }
    }
}
