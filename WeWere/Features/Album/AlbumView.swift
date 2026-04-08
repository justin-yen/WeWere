import SwiftUI
import Photos

struct AlbumView: View {
    let eventId: UUID

    @StateObject private var viewModel: AlbumViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sharedViewModel: SharedEventsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var downloadState: DownloadAllState = .idle
    @State private var downloadProgress: Int = 0

    enum DownloadAllState {
        case idle, downloading, done, failed
    }

    /// Event name from shared cache (instant) or fetched data
    private var eventName: String {
        sharedViewModel.events.first(where: { $0.id == eventId })?.name
            ?? viewModel.event?.name
            ?? ""
    }

    /// Photo count from shared cache (instant) or fetched data
    private var displayPhotoCount: Int {
        if !viewModel.photos.isEmpty { return viewModel.photos.count }
        if viewModel.photoCount > 0 { return viewModel.photoCount }
        return sharedViewModel.photoCounts[eventId] ?? 0
    }

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    init(eventId: UUID) {
        self.eventId = eventId
        _viewModel = StateObject(wrappedValue: AlbumViewModel(eventId: eventId))
    }

    var body: some View {
        ZStack {
            WeWereColors.surface
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Header
                    ZStack {
                        Text("WEWERE")
                            .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 16))
                            .tracking(3)
                            .foregroundStyle(WeWereColors.onSurface)

                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Back")
                                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                                }
                                .foregroundStyle(WeWereColors.onSurface)
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal, WeWereSpacing.md)
                    .padding(.top, WeWereSpacing.md)

                    // MARK: - Event title (from shared cache = instant)
                    Text(eventName)
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 28))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, WeWereSpacing.md)
                        .padding(.top, WeWereSpacing.lg)

                    // MARK: - Photo count + Peak time
                    HStack {
                        Text("\(displayPhotoCount) PHOTOGRAPHS")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                            .tracking(2)
                            .foregroundStyle(WeWereColors.outline)

                        Spacer()

                        if let peakTime = viewModel.peakTime {
                            HStack(spacing: 4) {
                                Text("PEAK")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                                    .foregroundStyle(WeWereColors.outline)
                                    .tracking(1)
                                Text(formattedPeakTime(peakTime))
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                                    .foregroundStyle(Color(hex: "D4A853"))
                            }
                        }
                    }
                    .padding(.horizontal, WeWereSpacing.md)
                    .padding(.top, WeWereSpacing.xxs)

                    // MARK: - Download All
                    if displayPhotoCount > 0 {
                        Button {
                            downloadAllPhotos()
                        } label: {
                            HStack(spacing: 6) {
                                switch downloadState {
                                case .idle:
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 12))
                                    Text("DOWNLOAD ALL")
                                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                                case .downloading:
                                    ProgressView()
                                        .tint(WeWereColors.onSurfaceVariant)
                                        .scaleEffect(0.7)
                                    Text("SAVING \(downloadProgress)/\(viewModel.photos.count)")
                                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                                case .done:
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12))
                                    Text("ALL SAVED")
                                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                                case .failed:
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 12))
                                    Text("RETRY DOWNLOAD")
                                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                                }
                            }
                            .foregroundStyle(downloadState == .done ? .green : WeWereColors.onSurfaceVariant)
                            .padding(.horizontal, WeWereSpacing.sm)
                            .padding(.vertical, WeWereSpacing.xs)
                            .overlay(
                                RoundedRectangle(cornerRadius: WeWereRadius.lg)
                                    .strokeBorder(
                                        downloadState == .done ? .green.opacity(0.5) : WeWereColors.outlineVariant,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .disabled(downloadState == .downloading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, WeWereSpacing.md)
                        .padding(.top, WeWereSpacing.xs)
                    }

                    // MARK: - Photo grid
                    if viewModel.isLoadingPhotos && viewModel.photos.isEmpty {
                        // Shimmer skeleton grid while photos load
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(0..<max(displayPhotoCount, 1), id: \.self) { _ in
                                PhotoSkeletonCell()
                            }
                        }
                        .padding(.horizontal, WeWereSpacing.md)
                        .padding(.top, WeWereSpacing.md)
                    } else if viewModel.photos.isEmpty && !viewModel.isLoadingPhotos {
                        VStack(spacing: WeWereSpacing.sm) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32))
                                .foregroundStyle(WeWereColors.outline)

                            Text("No photographs yet")
                                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                                .foregroundStyle(WeWereColors.outline)
                        }
                        .padding(.top, WeWereSpacing.xxxl)
                    } else {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(viewModel.photos) { photo in
                                NavigationLink(value: Route.photoDetail(photo.id, viewModel.photoURL(for: photo), eventId)) {
                                    PhotoGridItem(
                                        photo: photo,
                                        imageURL: viewModel.photoURL(for: photo)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, WeWereSpacing.md)
                        .padding(.top, WeWereSpacing.md)
                    }

                    // Bottom padding for tab bar clearance
                    Color.clear
                        .frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.load()
        }
    }

    private func formattedPeakTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).uppercased()
    }

    private func downloadAllPhotos() {
        guard downloadState != .downloading else { return }
        downloadState = .downloading
        downloadProgress = 0

        Task {
            var succeeded = 0
            for photo in viewModel.photos {
                guard let url = viewModel.photoURL(for: photo) else { continue }
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = UIImage(data: data) else { continue }

                    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                        PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        } completionHandler: { success, error in
                            if let error { cont.resume(throwing: error) }
                            else { cont.resume() }
                        }
                    }
                    succeeded += 1
                    downloadProgress = succeeded
                } catch {
                    print("Failed to save photo \(photo.id): \(error)")
                }
            }

            downloadState = succeeded == viewModel.photos.count ? .done : .failed
        }
    }
}

#Preview {
    NavigationStack {
        AlbumView(eventId: UUID())
            .environmentObject(AppState())
    }
}
