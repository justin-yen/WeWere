import SwiftUI

struct HomeView: View {
    @StateObject var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: WeWereSpacing.lg) {
                    // MARK: - Header Bar
                    headerBar

                    // MARK: - Live Events
                    if !viewModel.liveEvents.isEmpty {
                        liveEventsSection
                    }

                    // MARK: - Past Events
                    if !viewModel.readyToDevelop.isEmpty || !viewModel.developedEvents.isEmpty {
                        pastEventsSection
                    }

                    // MARK: - Empty State
                    if !viewModel.isLoading && viewModel.events.isEmpty {
                        emptyState
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, WeWereSpacing.md)
                .padding(.top, WeWereSpacing.sm)
            }

            // MARK: - Create Event FAB
            Button {
                appState.presentedSheet = .createEvent
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1a1c1c"))
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [.white, Color(hex: "#d4d4d4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.1), radius: 8, y: 2)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .task(id: authService.isAuthenticated) {
            guard authService.isAuthenticated else { return }
            await viewModel.loadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventCreated)) { _ in
            Task { await viewModel.loadEvents() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventUpdated)) { _ in
            Task { await viewModel.loadEvents() }
        }
        .refreshable {
            await viewModel.loadEvents()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ZStack {
            Text("WEWERE")
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 18))
                .tracking(4)
                .foregroundStyle(.white)

            HStack {
                Spacer()

                Button {
                    // Notifications action
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                }
            }
        }
        .padding(.vertical, WeWereSpacing.xs)
    }

    // MARK: - Live Events Section

    private var liveEventsSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            sectionHeader(
                title: "LIVE EVENTS",
                count: viewModel.liveEvents.count
            )

            TabView {
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
                    .padding(.horizontal, WeWereSpacing.xxxs)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: viewModel.liveEvents.count > 1 ? .automatic : .never))
            .frame(height: 296)
        }
    }

    // MARK: - Past Events Section

    private var pastEventsSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.lg) {
            sectionHeader(title: "PAST EVENTS", count: nil)

            VStack(alignment: .leading, spacing: WeWereSpacing.xs) {
                ForEach(viewModel.readyToDevelop) { event in
                    NavigationLink(value: Route.developFilm(event.id)) {
                        PastEventRow(event: event, isReadyToDevelop: true)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(viewModel.developedEvents) { event in
                    NavigationLink(value: Route.album(event.id)) {
                        PastEventRow(event: event, isReadyToDevelop: false)
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

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int?) -> some View {
        HStack(spacing: WeWereSpacing.xs) {
            Text(title)
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurfaceVariant)

            if let count {
                Text("\(count)")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
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
