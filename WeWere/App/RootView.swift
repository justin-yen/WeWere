import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @StateObject private var sharedViewModel = SharedEventsViewModel()
    @State private var showJoinEvent = false

    private var selectedTabRawValue: Binding<Int> {
        Binding(
            get: { appState.selectedTab.rawValue },
            set: { appState.selectedTab = Tab(rawValue: $0) ?? .home }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            WeWereHeader()

            ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab.animation(.easeInOut(duration: 0.3))) {
                NavigationStack(path: $appState.navigationPath) {
                    HomeView()
                        .navigationDestination(for: Route.self) { route in
                            destinationView(for: route)
                        }
                }
                .tag(Tab.home)

                NavigationStack {
                    PastEventsView()
                        .navigationDestination(for: Route.self) { route in
                            destinationView(for: route)
                        }
                }
                .tag(Tab.events)

                NavigationStack {
                    ProfileView()
                }
                .tag(Tab.profile)
            }
            // Hide default tab bar
            .toolbar(.hidden, for: .tabBar)

            WeWereTabBar(selectedTab: selectedTabRawValue)
        }
        }
        .environmentObject(sharedViewModel)
        .background(Color(hex: "#131313"))
        .onAppear {
            guard authService.isAuthenticated else { return }
            Task.detached { @MainActor in
                await sharedViewModel.loadEvents()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventCreated)) { _ in
            Task { await sharedViewModel.loadEvents() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventUpdated)) { _ in
            Task { await sharedViewModel.loadEvents() }
        }
        .sheet(item: Binding(
            get: { appState.presentedSheet.map { SheetRoute(route: $0) } },
            set: { appState.presentedSheet = $0?.route }
        )) { sheet in
            destinationView(for: sheet.route)
        }
        .onChange(of: appState.pendingDeepLink) { _, newValue in
            if let link = newValue {
                appState.pendingDeepLink = nil
                handleDeepLink(link)
            }
        }
    }

    @ViewBuilder
    func destinationView(for route: Route) -> some View {
        switch route {
        case .eventDetail(let id):
            EventDetailView(eventId: id)
        case .camera(let eventId):
            CameraView(eventId: eventId)
        case .developFilm(let eventId):
            DevelopFilmView(eventId: eventId)
        case .developingAnimation(let eventId):
            DevelopingAnimationView(eventId: eventId)
        case .album(let eventId):
            AlbumView(eventId: eventId)
        case .photoDetail(let photoId, let signedURL, let eventId):
            PhotoDetailView(photoId: photoId, signedURL: signedURL, eventId: eventId)
        case .joinEvent(let shareCode):
            JoinEventView(shareCode: shareCode)
        case .createEvent:
            CreateEventView()
        }
    }

    func handleDeepLink(_ route: Route) {
        if case .joinEvent = route {
            appState.presentedSheet = route
        } else {
            appState.navigationPath.append(route)
        }
    }
}

struct SheetRoute: Identifiable {
    let id = UUID()
    let route: Route
}
