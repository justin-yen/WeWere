import SwiftUI

struct PhotoDetailView: View {
    @StateObject private var viewModel: PhotoDetailViewModel
    @Environment(\.dismiss) var dismiss
    let signedURL: URL?
    @State private var commentText: String = ""
    @State private var saveState: SaveState = .idle
    @State private var selectedFilter: FilterStyle = .portra
    @State private var filteredDisplayImage: UIImage?
    @State private var isApplyingFilter = false

    enum SaveState {
        case idle, saving, saved, failed
    }

    init(photoId: UUID, signedURL: URL? = nil, eventId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: PhotoDetailViewModel(photoId: photoId, eventId: eventId))
        self.signedURL = signedURL
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top metadata bar
            HStack(alignment: .top) {
                // Filter picker
                Menu {
                    ForEach(FilterStyle.allCases) { style in
                        Button {
                            Task { await applyFilter(style) }
                        } label: {
                            Label {
                                Text(style.rawValue)
                            } icon: {
                                if selectedFilter == style {
                                    Image(systemName: "checkmark")
                                } else {
                                    Image(systemName: style.icon)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isApplyingFilter {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "camera.filters")
                                .font(.system(size: 14))
                        }
                        Text(selectedFilter.rawValue)
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: WeWereRadius.lg)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    )
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("PHOTO")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 9))
                        .foregroundStyle(WeWereColors.outline)
                        .tracking(1.2)

                    if let photographer = viewModel.photographer {
                        Text(photographer.resolvedDisplayName.uppercased())
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 12))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("CAPTURED")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 9))
                        .foregroundStyle(WeWereColors.outline)
                        .tracking(1.2)

                    if let photo = viewModel.photo {
                        Text(formattedDate(photo.createdAt))
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // MARK: - Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Photo
                    if let displayImage = filteredDisplayImage {
                        Image(uiImage: displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    } else if let url = signedURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                            case .failure:
                                photoPlaceholder
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity, minHeight: 300)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        photoPlaceholder
                    }

                    // MARK: - Reactions
                    ReactionBar(
                        myReactions: viewModel.myReactions,
                        reactionCounts: viewModel.reactionCounts,
                        reactorNames: viewModel.reactorNames
                    ) { emoji in
                        Task {
                            await viewModel.toggleReaction(emoji)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    // MARK: - Comments section
                    commentsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    // MARK: - Comment input
                    commentInputBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    // MARK: - Save button
                    Button {
                        guard saveState != .saving else { return }
                        saveState = .saving
                        Task {
                            do {
                                try await viewModel.saveToPhotoLibrary()
                                saveState = .saved
                            } catch {
                                saveState = .failed
                                print("Save failed: \(error)")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            switch saveState {
                            case .idle:
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 13, weight: .bold))
                                Text("SAVE TO CAMERA ROLL")
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 13))
                            case .saving:
                                ProgressView()
                                    .tint(Color(hex: "1a1c1c"))
                                Text("SAVING...")
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 13))
                            case .saved:
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                Text("SAVED")
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 13))
                            case .failed:
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                Text("FAILED - TAP TO RETRY")
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 13))
                            }
                        }
                        .foregroundStyle(Color(hex: "1a1c1c"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(saveState == .saved ? Color.green.opacity(0.8) : Color.white)
                        .cornerRadius(12)
                    }
                    .disabled(saveState == .saving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
        .enableSwipeBack()
        .task {
            viewModel.signedURL = signedURL
            await viewModel.load()
        }
    }

    // MARK: - Filter

    private func applyFilter(_ style: FilterStyle) async {
        guard style != selectedFilter else { return }
        selectedFilter = style

        // Portra is the server default — use signed URL
        if style == .portra {
            filteredDisplayImage = nil
            return
        }

        isApplyingFilter = true
        defer { isApplyingFilter = false }

        // Download the image data from signed URL
        guard let url = signedURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if style == .none {
                // For "Original", try to get the unfiltered version from storage
                if let photo = viewModel.photo {
                    let photoService = PhotoService()
                    if let originalData = try? await photoService.downloadPhotoData(photo: photo),
                       let img = UIImage(data: originalData) {
                        filteredDisplayImage = img
                        return
                    }
                }
                // Fallback: just show what we have
                filteredDisplayImage = UIImage(data: data)
            } else {
                filteredDisplayImage = RetroFilter.apply(style: style, to: data)
            }
        } catch {
            print("Failed to apply filter: \(error)")
        }
    }

    // MARK: - Comments list

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.comments.isEmpty {
                Text("COMMENTS")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                    .foregroundStyle(WeWereColors.outline)
                    .tracking(1.2)

                ForEach(viewModel.comments) { comment in
                    commentRow(comment)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commentRow(_ comment: PhotoComment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(comment.userName)
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                    .foregroundStyle(.white)

                Text(relativeTime(comment.createdAt))
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                    .foregroundStyle(WeWereColors.outline)
            }

            Text(comment.text)
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Comment input bar

    private var commentInputBar: some View {
        HStack(spacing: 8) {
            TextField("Add a comment...", text: $commentText)
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.onSurface)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "191919"))
                .cornerRadius(8)

            Button {
                let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                let captured = text
                commentText = ""
                Task {
                    await viewModel.addComment(text: captured)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Helpers

    private var photoPlaceholder: some View {
        Image(systemName: "photo")
            .foregroundStyle(WeWereColors.outline)
            .font(.system(size: 48))
            .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy • hh:mm a"
        return formatter.string(from: date).uppercased()
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
