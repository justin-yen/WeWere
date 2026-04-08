import Foundation

enum DeepLink {
    case joinEvent(shareCode: String)
    case eventDetail(id: UUID)
}

enum DeepLinkService {
    static func parse(url: URL) -> DeepLink? {
        print("DEBUG deeplink: url=\(url), scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil"), path=\(url.path)")

        // For custom scheme: wewere://event/SHARECODE
        // url.host = "event", url.path = "/SHARECODE"
        if url.scheme == "wewere" {
            if url.host == "event" {
                let code = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !code.isEmpty {
                    print("DEBUG deeplink: parsed share code = \(code)")
                    if let uuid = UUID(uuidString: code) {
                        return .eventDetail(id: uuid)
                    } else {
                        return .joinEvent(shareCode: code)
                    }
                }
            }
            return nil
        }

        // For universal links: https://wewere.app/event/SHARECODE
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)

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
        print("DEBUG deeplink: handling \(deepLink)")
        switch deepLink {
        case .joinEvent(let shareCode):
            appState.pendingDeepLink = .joinEvent(shareCode: shareCode)
        case .eventDetail(let id):
            appState.pendingDeepLink = .eventDetail(id)
        }
    }
}
