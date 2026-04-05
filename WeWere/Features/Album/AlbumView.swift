import SwiftUI

struct AlbumView: View {
    let eventId: UUID

    @StateObject private var viewModel: AlbumViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

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

                    // MARK: - Event title
                    Text(viewModel.event?.name ?? "")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 28))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, WeWereSpacing.md)
                        .padding(.top, WeWereSpacing.lg)

                    // MARK: - Photo count
                    Text("\(viewModel.photos.count) PHOTOGRAPHS")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                        .tracking(2)
                        .foregroundStyle(WeWereColors.outline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, WeWereSpacing.md)
                        .padding(.top, WeWereSpacing.xxs)

                    // MARK: - Action bar
                    HStack {
                        Button {
                            // Download all action
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))
                                Text("DOWNLOAD ALL")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                            }
                            .foregroundStyle(WeWereColors.onSurfaceVariant)
                            .padding(.horizontal, WeWereSpacing.sm)
                            .padding(.vertical, WeWereSpacing.xs)
                            .overlay(
                                RoundedRectangle(cornerRadius: WeWereRadius.lg)
                                    .strokeBorder(WeWereColors.outlineVariant, lineWidth: 1)
                            )
                        }

                        Spacer()
                    }
                    .padding(.horizontal, WeWereSpacing.md)
                    .padding(.top, WeWereSpacing.md)

                    // MARK: - Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: WeWereSpacing.xs) {
                            ForEach(viewModel.filters, id: \.self) { filter in
                                filterChip(title: filter, isSelected: viewModel.selectedFilter == filter)
                                    .onTapGesture {
                                        viewModel.selectedFilter = filter
                                    }
                            }
                        }
                        .padding(.horizontal, WeWereSpacing.md)
                    }
                    .padding(.top, WeWereSpacing.md)

                    // MARK: - Photo grid
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(WeWereColors.outline)
                            .padding(.top, WeWereSpacing.xxxl)
                    } else if viewModel.photos.isEmpty {
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
                                PhotoGridItem(
                                    photo: photo,
                                    imageURL: viewModel.photoURL(for: photo)
                                )
                                .onTapGesture {
                                    appState.navigationPath.append(Route.photoDetail(photo.id))
                                }
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

    // MARK: - Filter Chip

    @ViewBuilder
    private func filterChip(title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
            .foregroundStyle(isSelected ? WeWereColors.onPrimary : WeWereColors.onSurfaceVariant)
            .padding(.horizontal, WeWereSpacing.sm)
            .padding(.vertical, WeWereSpacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? .white : WeWereColors.secondaryContainer)
            )
    }
}

#Preview {
    NavigationStack {
        AlbumView(eventId: UUID())
            .environmentObject(AppState())
    }
}
