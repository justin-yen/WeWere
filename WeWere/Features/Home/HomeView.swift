import SwiftUI

struct HomeView: View {
    @StateObject private var photoStackViewModel = PhotoStackViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var viewModel: SharedEventsViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WeWereSpacing.lg) {
                // MARK: - Live Events
                if !viewModel.liveEvents.isEmpty {
                    liveEventsSection
                }

                // MARK: - Ready to Develop
                if !viewModel.readyToDevelop.isEmpty {
                    readyToDevelopSection
                }

                // MARK: - Past Moments Photo Stack
                if !photoStackViewModel.stackPhotos.isEmpty || !viewModel.developedEvents.isEmpty {
                    pastMomentsSection
                }

                // MARK: - Empty State
                if !viewModel.isLoading && viewModel.liveEvents.isEmpty && viewModel.readyToDevelop.isEmpty && viewModel.developedEvents.isEmpty {
                    emptyState
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, WeWereSpacing.md)
            .padding(.top, WeWereSpacing.sm)
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .onChange(of: viewModel.developedEvents.count) { _, newCount in
            guard newCount > 0 else { return }
            let events = viewModel.developedEvents
            Task.detached { @MainActor in
                await photoStackViewModel.loadPhotos(developedEvents: events)
            }
        }
        .refreshable {
            photoStackViewModel.invalidateCache()
            await viewModel.loadEvents()
            await photoStackViewModel.loadPhotos(developedEvents: viewModel.developedEvents)
        }
    }

    // MARK: - Live Events Section

    private var liveEventsSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            sectionHeader(
                title: "LIVE EVENTS",
                count: viewModel.liveEvents.count
            )

            VStack(spacing: WeWereSpacing.sm) {
                ForEach(viewModel.liveEvents) { event in
                    NavigationLink(value: Route.eventDetail(event.id)) {
                        LiveEventCard(
                            event: event,
                            photoCount: viewModel.photoCounts[event.id] ?? 0,
                            memberCount: viewModel.memberCounts[event.id] ?? 1,
                            onCamera: {
                                appState.presentedSheet = .camera(event.id)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Past Events Section

    private var readyToDevelopSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            sectionHeader(title: "READY TO DEVELOP", count: viewModel.readyToDevelop.count)

            VStack(alignment: .leading, spacing: WeWereSpacing.xs) {
                ForEach(viewModel.readyToDevelop) { event in
                    NavigationLink(value: Route.developFilm(event.id)) {
                        PastEventRow(event: event, isReadyToDevelop: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: WeWereSpacing.md) {
            Spacer().frame(height: 120)

            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(WeWereColors.outlineVariant)

            Text("NO EVENTS YET")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 14))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurfaceVariant)

            Text("Create an event or join one\nwith a shared link.")
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.outline)
                .multilineTextAlignment(.center)

            Button {
                appState.presentedSheet = .createEvent
            } label: {
                Text("CREATE EVENT")
                    .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                    .foregroundStyle(Color(hex: "#1a1c1c"))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.white, Color(hex: "#d4d4d4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, WeWereSpacing.sm)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Past Moments Section

    private var pastMomentsSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            sectionHeader(title: "PAST MOMENTS", count: nil)

            if photoStackViewModel.stackPhotos.isEmpty {
                PhotoStackEmptyView()
            } else {
                PhotoStackView(photos: photoStackViewModel.stackPhotos) { photo in
                    appState.navigationPath.append(Route.photoDetail(photo.photoId, photo.url, photo.eventId))
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int?) -> some View {
        HStack(spacing: WeWereSpacing.xs) {
            Text(title)
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 20))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurface)

            if let count {
                Text("\(count)")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 14))
                    .foregroundStyle(WeWereColors.outline)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppState())
    }
}
