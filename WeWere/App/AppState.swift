import SwiftUI

enum Tab: Int, CaseIterable {
    case home = 0
    case events = 1
    case profile = 2
}

enum Route: Hashable {
    case eventDetail(UUID)
    case camera(UUID)
    case developFilm(UUID)
    case developingAnimation(UUID)
    case album(UUID)
    case photoDetail(UUID, URL?, UUID?) // photoId, signedURL, eventId
    case joinEvent(shareCode: String)
    case createEvent
    case attendees(UUID)
}

extension Notification.Name {
    static let eventCreated = Notification.Name("eventCreated")
    static let eventUpdated = Notification.Name("eventUpdated")
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var navigationPath = NavigationPath()       // Home tab
    @Published var eventsNavPath = NavigationPath()        // Events tab
    @Published var profileNavPath = NavigationPath()       // Profile tab
    @Published var presentedSheet: Route?
    @Published var pendingDeepLink: Route?

    /// Navigation path for the currently active tab.
    var activeNavPath: NavigationPath {
        switch selectedTab {
        case .home: return navigationPath
        case .events: return eventsNavPath
        case .profile: return profileNavPath
        }
    }

    /// Whether the current tab can go back.
    var canGoBack: Bool {
        !activeNavPath.isEmpty
    }

    /// Pop the current tab's navigation stack.
    func goBack() {
        switch selectedTab {
        case .home: if !navigationPath.isEmpty { navigationPath.removeLast() }
        case .events: if !eventsNavPath.isEmpty { eventsNavPath.removeLast() }
        case .profile: if !profileNavPath.isEmpty { profileNavPath.removeLast() }
        }
    }
}
