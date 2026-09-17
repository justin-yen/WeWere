import SwiftUI

@main
struct WeWereApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()
    #if DEBUG && STAGING && targetEnvironment(simulator)
    @State private var showSessionValidation = false
    #endif

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
                    } else if let message = authService.recoveryError {
                        VStack(spacing: 20) {
                            Text(message).multilineTextAlignment(.center)
                            Button(authService.isRecovering ? "Connecting…" : "Try again") {
                                Task { await authService.initialize() }
                            }
                            .disabled(authService.isRecovering)
                            Button("Sign out and sign in again") {
                                Task {
                                    do { try await authService.signOut() }
                                    catch { authService.recoveryError = error.localizedDescription }
                                }
                            }
                            .disabled(authService.isRecovering)
                        }.padding(32)
                    } else {
                        AuthFlowView()
                    }
                }
            }
            .environmentObject(appState)
            .environmentObject(authService)
            #if DEBUG && STAGING && targetEnvironment(simulator)
            .overlay(alignment: .bottomTrailing) {
                Button("Session tests") { showSessionValidation = true }
                    .font(.caption2)
                    .padding(6)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.black)
            }
            .sheet(isPresented: $showSessionValidation) {
                SessionValidationView().environmentObject(authService)
            }
            #endif
            .preferredColorScheme(.dark)
            .overlay(alignment: .topTrailing) {
                if AppEnvironment.isStaging {
                    Text("STAGING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(4)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.black)
                        .allowsHitTesting(false)
                        .accessibilityLabel("Staging environment")
                }
            }
            .onOpenURL { url in
                if let deepLink = DeepLinkService.parse(url: url) {
                    DeepLinkService.handle(deepLink, appState: appState)
                }
            }
            .task {
                await authService.initialize()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && !authService.isInitializing {
                    Task { await authService.initialize() }
                }
            }
            .onChange(of: authService.isAuthenticated) { _, authenticated in
                if !authenticated {
                    appState.navigationPath = NavigationPath()
                    appState.eventsNavPath = NavigationPath()
                    appState.profileNavPath = NavigationPath()
                    appState.presentedSheet = nil
                }
            }
        }
    }
}
