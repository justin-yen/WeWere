import Foundation

@MainActor
class AlbumViewModel: ObservableObject {
    let eventId: UUID
    @Published var event: Event?
    @Published var photos: [Photo] = []
    @Published var photoURLs: [UUID: URL] = [:]
    @Published var isLoading = true
    @Published var isLoadingPhotos = true
    @Published var photoCount: Int = 0
    @Published var peakTime: Date?
    @Published var errorMessage: String?

    private let eventService = EventService()
    private let api = APIClient.shared
    private let photoService = PhotoService()

    // MARK: - Static cache (persists across view rebuilds)
    static var cachedPhotos: [UUID: [Photo]] = [:]

    /// Access all cached photos across events (for PhotoDetailViewModel)
    static var allCachedPhotos: [UUID: [Photo]] { cachedPhotos }
    private static var cachedURLs: [UUID: [UUID: URL]] = [:]  // [eventId: [photoId: URL]]
    private static var cachedEvents: [UUID: Event] = [:]

    init(eventId: UUID) {
        self.eventId = eventId

        // Restore from cache immediately
        if let cached = Self.cachedPhotos[eventId] {
            self.photos = cached
            self.photoURLs = Self.cachedURLs[eventId] ?? [:]
            self.event = Self.cachedEvents[eventId]
            self.isLoading = false
        }
    }

    /// Pre-populate event info from shared cache so the header renders instantly
    func setEventInfo(event: Event?, photoCount: Int) {
        if self.event == nil { self.event = event }
        if self.photoCount == 0 { self.photoCount = photoCount }
    }

    func load() async {
        // If already cached, skip network fetch
        if !photos.isEmpty && !photoURLs.isEmpty {
            isLoading = false
            isLoadingPhotos = false
            return
        }

        // Show skeleton immediately -- event info already set from shared cache
        isLoading = false
        isLoadingPhotos = true

        // Fetch photos and peak time concurrently
        async let peakTimeFetch: Void = fetchPeakTime()

        do {
            let photoResponses = try await photoService.fetchPhotos(eventId: eventId)
            photos = photoResponses.map { $0.toPhoto }
            photoCount = photos.count

            for pr in photoResponses {
                if let signedUrlString = pr.signedUrl,
                   let url = URL(string: signedUrlString) {
                    photoURLs[pr.id] = url
                } else {
                    let photo = pr.toPhoto
                    if let url = photoService.getFilteredPhotoURL(photo: photo) {
                        photoURLs[photo.id] = url
                    }
                }
            }

            Self.cachedPhotos[eventId] = photos
            Self.cachedURLs[eventId] = photoURLs
            Self.cachedEvents[eventId] = event
        } catch {
            print("Album load error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoadingPhotos = false

        // Ensure peak time fetch completes
        await peakTimeFetch
    }

    func photoURL(for photo: Photo) -> URL? {
        return photoURLs[photo.id]
    }

    private func fetchPeakTime() async {
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
                peakTime = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            }
        } catch {
            print("Peak time fetch error: \(error)")
        }
    }

    /// Force refresh (e.g. pull to refresh)
    func refresh() async {
        Self.cachedPhotos.removeValue(forKey: eventId)
        Self.cachedURLs.removeValue(forKey: eventId)
        Self.cachedEvents.removeValue(forKey: eventId)
        photos = []
        photoURLs = [:]
        await load()
    }
}
