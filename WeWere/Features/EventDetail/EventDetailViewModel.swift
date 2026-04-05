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

    private let eventService = EventService()
    private let photoService = PhotoService()

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Load event
        do {
            event = try await eventService.fetchEvent(byId: eventId)
        } catch {
            print("Failed to load event: \(error)")
        }

        // Step 2: Load members
        do {
            members = try await eventService.fetchMembersWithUsers(eventId: eventId)
        } catch {
            print("Failed to load members with users: \(error)")
            // Fallback: try loading members without user join
            do {
                let plainMembers = try await eventService.fetchMembers(eventId: eventId)
                members = plainMembers.map { member in
                    let placeholder = AppUser(
                        id: member.userId,
                        authId: UUID(),
                        firstName: "",
                        lastName: "",
                        displayName: "Member",
                        instagramHandle: nil,
                        phoneNumber: nil,
                        avatarUrl: nil,
                        pushToken: nil,
                        createdAt: Date()
                    )
                    return (member, placeholder)
                }
            } catch {
                print("Failed to load members fallback: \(error)")
            }
        }

        // Step 3: Load photo count
        do {
            photoCount = try await photoService.getPhotoCount(eventId: eventId)
        } catch {
            print("Failed to load photo count: \(error)")
        }

        // Step 4: Check if current user is host
        await checkIsHost()

    }

    private func checkIsHost() async {
        // Method 1: Check via event.hostId matching current user
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let authId = session.user.id

            // Check member role
            for (member, user) in members {
                if user.authId == authId && member.role == .host {
                    isHost = true
                    return
                }
            }

            // Check via event hostId
            if let event {
                let currentUser: AppUser = try await SupabaseManager.shared.client
                    .from("users")
                    .select()
                    .eq("auth_id", value: authId.uuidString)
                    .single()
                    .execute()
                    .value

                if event.hostId == currentUser.id {
                    isHost = true
                    return
                }
            }
        } catch {
            print("Failed to check host status: \(error)")
        }

        // Method 2: Check via plain members (if user join failed)
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let authId = session.user.id

            let currentUser: AppUser = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("auth_id", value: authId.uuidString)
                .single()
                .execute()
                .value

            let plainMembers = try await eventService.fetchMembers(eventId: eventId)
            if plainMembers.contains(where: { $0.userId == currentUser.id && $0.role == .host }) {
                isHost = true
            }
        } catch {
            print("Failed to check host status (fallback): \(error)")
        }
    }

    func subscribeToUpdates() {
        eventService.subscribeToPhotoCount(eventId: eventId) { [weak self] count in
            Task { @MainActor in
                self?.photoCount = count
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
