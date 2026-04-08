import Foundation
import SwiftUI

// MARK: - Backend request for develop

struct DevelopFilmRequest: Encodable {
    let eventId: UUID

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
    }
}

@MainActor
class DevelopFilmViewModel: ObservableObject {
    let eventId: UUID
    @Published var event: Event?
    @Published var photoCount: Int = 0
    @Published var isDeveloping = false
    @Published var peakTime: Date?
    @Published var errorMessage: String?

    private let eventService = EventService()
    private let photoService = PhotoService()
    private let api = APIClient.shared

    init(eventId: UUID) {
        self.eventId = eventId
    }

    func load() async {
        async let eventFetch = eventService.fetchEvent(byId: eventId)
        async let countFetch = photoService.getPhotoCount(eventId: eventId)

        do { event = try await eventFetch } catch { errorMessage = error.localizedDescription }
        do { photoCount = try await countFetch } catch {}

        await calculatePeakTime()
    }

    func calculatePeakTime() async {
        struct PeakTimeResponse: Decodable {
            let peakStart: Date?
            let peakEnd: Date?
            let photoCount: Int

            enum CodingKeys: String, CodingKey {
                case peakStart = "peak_start"
                case peakEnd = "peak_end"
                case photoCount = "photo_count"
            }
        }

        do {
            let response: PeakTimeResponse = try await api.get(
                "/events/\(eventId.uuidString)/photos/peak-time"
            )
            if let start = response.peakStart, let end = response.peakEnd {
                // Use midpoint of peak window
                peakTime = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            }
        } catch {
            print("Peak time fetch error: \(error)")
        }
    }

    func developFilm() async throws {
        isDeveloping = true

        // Call backend to mark membership as developed
        do {
            let _: EmptyResponse = try await api.post(
                "/events/\(eventId.uuidString)/develop",
                body: DevelopFilmRequest(eventId: eventId)
            )
        } catch {
            isDeveloping = false
            throw error
        }
    }
}
