import Foundation
import UserNotifications

final class PushNotificationService {
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    func registerToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        Task { @MainActor in
            try? await authService.registerPushToken(token)
        }
    }
}
