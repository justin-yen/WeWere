import SwiftUI

@main
struct WeWereApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if authService.isInitializing {
                        // Splash / loading
                        ZStack {
                            WeWereColors.surface.ignoresSafeArea()
                            Text("WEWERE")
                                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 28))
                                .tracking(4)
                                .foregroundStyle(WeWereColors.onSurface)
                        }
                    } else if authService.isAuthenticated {
                        RootView()
                    } else {
                        AuthFlowView()
                    }
                }
            }
            .environmentObject(appState)
            .environmentObject(authService)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                if let deepLink = DeepLinkService.parse(url: url) {
                    DeepLinkService.handle(deepLink, appState: appState)
                }
            }
            .task {
                await authService.initialize()
            }
        }
    }
}
