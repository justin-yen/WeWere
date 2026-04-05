import Foundation

enum DeepLink {
    case joinEvent(shareCode: String)
    case eventDetail(id: UUID)
}

enum DeepLinkService {
    static func parse(url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)

        // Handle wewere://event/<shareCode> or https://wewere.app/event/<shareCode>
        if pathComponents.count >= 2, pathComponents[0] == "event" {
            let code = pathComponents[1]
            if let uuid = UUID(uuidString: code) {
                return .eventDetail(id: uuid)
            } else {
                return .joinEvent(shareCode: code)
            }
        }

        return nil
    }

    @MainActor
    static func handle(_ deepLink: DeepLink, appState: AppState) {
        switch deepLink {
        case .joinEvent(let shareCode):
            appState.pendingDeepLink = .joinEvent(shareCode: shareCode)
        case .eventDetail(let id):
            appState.pendingDeepLink = .eventDetail(id)
        }
    }
}
