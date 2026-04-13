import SwiftUI

// MARK: - Unsplash photo model

struct UnsplashPhoto: Identifiable, Equatable {
    let id: String
    let urlSmall: String
    let urlRegular: String
    let photographer: String
    let photographerUrl: String
    let color: String?
}

// MARK: - Cover Photo Picker

struct CoverPhotoPickerView: View {
    let eventName: String
    let eventDescription: String
    let onSelect: (UnsplashPhoto) -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var photos: [UnsplashPhoto] = []
    @State private var selectedPhoto: UnsplashPhoto?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var hasSearched = false

    private let api = APIClient.shared
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("COVER PHOTO")
                    .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 18))
                    .foregroundStyle(.white)
                    .tracking(2)

                Spacer()

                Button {
                    onSkip()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                        .background(WeWereColors.surfaceContainerHigh)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(WeWereColors.outline)

                TextField("", text: $searchText, prompt:
                    Text("Search photos...")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                        .foregroundStyle(WeWereColors.outlineVariant)
                )
                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                .foregroundStyle(.white)
                .submitLabel(.search)
                .onSubmit {
                    Task { await search(query: searchText) }
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(WeWereColors.outline)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(WeWereColors.surfaceContainerLow)
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Label
            if !photos.isEmpty {
                HStack {
                    Text("SUGGESTED FOR YOUR EVENT")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                        .foregroundStyle(WeWereColors.outline)
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            // Photo grid
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if photos.isEmpty && hasSearched {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundStyle(WeWereColors.outline)
                    Text("No photos found")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                        .foregroundStyle(WeWereColors.outline)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(photos) { photo in
                            photoCell(photo)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Attribution
                    if !photos.isEmpty {
                        Text("Photos from Unsplash")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                            .foregroundStyle(WeWereColors.outline)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                }
            }

            // Bottom buttons
            VStack(spacing: 10) {
                Button {
                    if let photo = selectedPhoto {
                        onSelect(photo)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("USE THIS PHOTO")
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 13))
                    }
                    .foregroundStyle(Color(hex: "1a1c1c"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [.white, Color(hex: "d4d4d4")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(selectedPhoto == nil)
                .opacity(selectedPhoto != nil ? 1.0 : 0.4)

                Button {
                    onSkip()
                    dismiss()
                } label: {
                    Text("Skip for now")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 13))
                        .foregroundStyle(WeWereColors.outline)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(WeWereColors.surface.ignoresSafeArea())
        .task {
            // Auto-search on appear if event name is long enough
            if eventName.count >= 3 {
                await search(query: nil)
            }
        }
    }

    // MARK: - Photo cell

    private func photoCell(_ photo: UnsplashPhoto) -> some View {
        let isSelected = selectedPhoto?.id == photo.id

        return AsyncImage(url: URL(string: photo.urlSmall)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(4/3, contentMode: .fill)
                    .clipped()
            case .failure:
                placeholder(color: photo.color)
            case .empty:
                placeholder(color: photo.color)
                    .overlay(ProgressView().tint(.white).scaleEffect(0.7))
            @unknown default:
                placeholder(color: photo.color)
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .padding(6)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(photo.photographer)
                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 8))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 2)
                .padding(6)
                .lineLimit(1)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPhoto = photo
            }
        }
    }

    private func placeholder(color: String?) -> some View {
        Rectangle()
            .fill(Color(hex: color ?? "282828"))
            .aspectRatio(4/3, contentMode: .fit)
    }

    // MARK: - Search

    private func search(query: String?) async {
        isLoading = true
        defer {
            isLoading = false
            hasSearched = true
        }

        let effectiveQuery = (query?.isEmpty ?? true) ? nil : query

        do {
            var path = "/unsplash/search?event_name=\(eventName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? eventName)"
            if let desc = eventDescription.isEmpty ? nil : eventDescription {
                path += "&event_description=\(desc.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? desc)"
            }
            // If user typed a custom query, override the event_name param
            if let q = effectiveQuery {
                path = "/unsplash/search?event_name=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
            }

            let response: UnsplashSearchResponse = try await api.get(path)
            photos = response.photos.map { p in
                UnsplashPhoto(
                    id: p.id,
                    urlSmall: p.urlSmall,
                    urlRegular: p.urlRegular,
                    photographer: p.photographer,
                    photographerUrl: p.photographerUrl,
                    color: p.color
                )
            }
            if let first = photos.first {
                selectedPhoto = first
            }
            if searchText.isEmpty {
                searchText = response.query
            }
        } catch {
            print("Unsplash search failed: \(error)")
            photos = []
        }
    }
}

// MARK: - API response

private struct UnsplashSearchResponse: Decodable {
    let photos: [UnsplashPhotoResponse]
    let query: String
}

private struct UnsplashPhotoResponse: Decodable {
    let id: String
    let urlSmall: String
    let urlRegular: String
    let photographer: String
    let photographerUrl: String
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id
        case urlSmall = "url_small"
        case urlRegular = "url_regular"
        case photographer
        case photographerUrl = "photographer_url"
        case color
    }
}
