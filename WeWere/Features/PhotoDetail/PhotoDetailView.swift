import SwiftUI

struct PhotoDetailView: View {
    @StateObject private var viewModel: PhotoDetailViewModel
    @Environment(\.dismiss) var dismiss

    init(photoId: UUID) {
        _viewModel = StateObject(wrappedValue: PhotoDetailViewModel(photoId: photoId))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Photo
            if let photo = viewModel.photo {
                let photoService = PhotoService()
                if let url = photoService.getFilteredPhotoURL(photo: photo) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(WeWereColors.outline)
                                .font(.system(size: 48))
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(WeWereColors.outline)
                        .font(.system(size: 48))
                }
            }

            // Top overlay
            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .overlay(alignment: .top) {
                    HStack(alignment: .top) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let photographer = viewModel.photographer {
                                Text(photographer.displayName)
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                    .foregroundStyle(.white)
                            }

                            if let photo = viewModel.photo {
                                Text(photo.createdAt, style: .date)
                                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                                    .foregroundStyle(WeWereColors.outline)
                                + Text(" ")
                                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                                + Text(photo.createdAt, style: .time)
                                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                                    .foregroundStyle(WeWereColors.outline)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Bottom overlay
            VStack {
                Spacer()

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .overlay(alignment: .bottom) {
                    VStack(spacing: 16) {
                        // Save button
                        Button {
                            Task {
                                try? await viewModel.saveToPhotoLibrary()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 13, weight: .bold))
                                Text("SAVE TO CAMERA ROLL")
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 13))
                            }
                            .foregroundStyle(Color(hex: "1a1c1c"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(12)
                        }

                        // Reaction bar
                        ReactionBar(
                            reactionCounts: viewModel.reactionCounts,
                            myReactions: viewModel.myReactions
                        ) { emoji in
                            Task {
                                await viewModel.toggleReaction(emoji)
                            }
                        }

                        // Metadata row
                        Text("ISO 800 | f/1.8 | 1/60")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                            .foregroundStyle(WeWereColors.outline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .task {
            await viewModel.load()
        }
    }
}
