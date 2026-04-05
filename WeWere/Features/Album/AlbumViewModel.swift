import Foundation

@MainActor
class AlbumViewModel: ObservableObject {
    let eventId: UUID
    @Published var event: Event?
    @Published var photos: [Photo] = []
    @Published var photoURLs: [UUID: URL] = [:]
    @Published var isLoading = true
    @Published var selectedFilter: String = "ALL PHOTOS"
    @Published var errorMessage: String?

    let filters = ["ALL PHOTOS", "PORTRAITS", "CANDID", "BACKSTAGE", "ATMOSPHERE"]

    private let eventService = EventService()
    private let photoService = PhotoService()

    // MARK: - Static cache (persists across view rebuilds)
    private static var cachedPhotos: [UUID: [Photo]] = [:]
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

    func load() async {
        // If already cached, skip network fetch
        if !photos.isEmpty && !photoURLs.isEmpty {
            isLoading = false
            return
        }

        isLoading = true
        do {
            async let fetchedEvent = eventService.fetchEvent(byId: eventId)
            async let fetchedPhotos = photoService.fetchPhotos(eventId: eventId)

            event = try await fetchedEvent
            photos = try await fetchedPhotos

            // Generate signed URLs for all photos
            for photo in photos {
                let path = photo.filteredStoragePath ?? photo.storagePath
                do {
                    let url = try await photoService.createSignedURL(path: path, expiresIn: 3600)
                    photoURLs[photo.id] = url
                } catch {
                    print("Failed to create signed URL for \(photo.id): \(error)")
                }
            }

            // Save to cache
            Self.cachedPhotos[eventId] = photos
            Self.cachedURLs[eventId] = photoURLs
            Self.cachedEvents[eventId] = event
        } catch {
            print("Album load error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func photoURL(for photo: Photo) -> URL? {
        return photoURLs[photo.id]
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
