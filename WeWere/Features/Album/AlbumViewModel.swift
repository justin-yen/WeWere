import Foundation
import UIKit

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

    // Filter state
    @Published var selectedFilter: FilterStyle = .portra
    @Published var filteredImages: [UUID: UIImage] = [:]
    @Published var isApplyingFilter = false
    @Published var filterProgress: Int = 0

    private let eventService = EventService()
    private let api = APIClient.shared
    private let photoService = PhotoService()

    // Original image data cache (downloaded once, reused across filter changes)
    private var originalImageData: [UUID: Data] = [:]

    // Per-filter image cache: [filterStyle: [photoId: UIImage]]
    private var filterCache: [FilterStyle: [UUID: UIImage]] = [:]

    // MARK: - Static cache (persists across view rebuilds)
    static var cachedPhotos: [UUID: [Photo]] = [:]
    static var allCachedPhotos: [UUID: [Photo]] { cachedPhotos }
    static var cachedURLs: [UUID: [UUID: URL]] = [:]
    private static var cachedEvents: [UUID: Event] = [:]

    init(eventId: UUID) {
        self.eventId = eventId

        if let cached = Self.cachedPhotos[eventId] {
            self.photos = cached
            self.photoURLs = Self.cachedURLs[eventId] ?? [:]
            self.event = Self.cachedEvents[eventId]
            self.isLoading = false
        }
    }

    func setEventInfo(event: Event?, photoCount: Int) {
        if self.event == nil { self.event = event }
        if self.photoCount == 0 { self.photoCount = photoCount }
    }

    func load() async {
        if !photos.isEmpty && !photoURLs.isEmpty {
            isLoading = false
            isLoadingPhotos = false
            return
        }

        isLoading = false
        isLoadingPhotos = true

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

        await peakTimeFetch
    }

    func photoURL(for photo: Photo) -> URL? {
        return photoURLs[photo.id]
    }

    /// Returns the filtered UIImage for a photo if available, nil otherwise (use URL fallback).
    func filteredImage(for photo: Photo) -> UIImage? {
        return filteredImages[photo.id]
    }

    /// Whether we're using URL-based display (default Portra from server) or client-side filtered images.
    var isUsingServerFilter: Bool {
        selectedFilter == .portra && filteredImages.isEmpty
    }

    // MARK: - Filter Switching

    func applyFilter(_ style: FilterStyle) async {
        guard style != selectedFilter || filteredImages.isEmpty else { return }
        selectedFilter = style

        // Portra is the server default — use signed URLs directly
        if style == .portra && filterCache[.portra] == nil {
            filteredImages = [:]
            return
        }

        // Check cache first
        if let cached = filterCache[style], cached.count == photos.count {
            filteredImages = cached
            return
        }

        // Need to download originals and apply filter
        isApplyingFilter = true
        filterProgress = 0

        var results: [UUID: UIImage] = [:]

        await withTaskGroup(of: (UUID, UIImage?).self) { group in
            for photo in photos {
                group.addTask { [weak self] in
                    guard let self else { return (photo.id, nil) }
                    let data = await self.getOriginalData(for: photo)
                    guard let data else { return (photo.id, nil) }

                    if style == .none {
                        return (photo.id, UIImage(data: data))
                    }

                    let filtered = RetroFilter.apply(style: style, to: data)
                    return (photo.id, filtered)
                }
            }

            for await (photoId, image) in group {
                if let image {
                    results[photoId] = image
                }
                filterProgress += 1
            }
        }

        filterCache[style] = results
        filteredImages = results
        isApplyingFilter = false
    }

    /// Download original photo data, caching for reuse.
    /// Tries Supabase Storage first, falls back to signed URL.
    private func getOriginalData(for photo: Photo) async -> Data? {
        if let cached = originalImageData[photo.id] {
            return cached
        }

        // Try direct Supabase storage download
        do {
            let data = try await photoService.downloadPhotoData(photo: photo)
            originalImageData[photo.id] = data
            return data
        } catch {
            print("Storage download failed for \(photo.id), trying signed URL...")
        }

        // Fallback: download from the signed URL
        guard let url = photoURLs[photo.id] else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            originalImageData[photo.id] = data
            return data
        } catch {
            print("Signed URL download also failed for \(photo.id): \(error)")
            return nil
        }
    }

    // MARK: - Peak Time

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

    func refresh() async {
        Self.cachedPhotos.removeValue(forKey: eventId)
        Self.cachedURLs.removeValue(forKey: eventId)
        Self.cachedEvents.removeValue(forKey: eventId)
        photos = []
        photoURLs = [:]
        filteredImages = [:]
        filterCache = [:]
        originalImageData = [:]
        await load()
    }
}
