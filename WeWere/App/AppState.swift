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
    case photoDetail(UUID)
    case joinEvent(shareCode: String)
    case createEvent
}

extension Notification.Name {
    static let eventCreated = Notification.Name("eventCreated")
    static let eventUpdated = Notification.Name("eventUpdated")
}

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: Route?
    @Published var pendingDeepLink: Route?
}
