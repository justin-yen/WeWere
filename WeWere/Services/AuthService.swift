import Foundation
import OSLog
import Supabase

// MARK: - Backend Response Types

struct SendOTPResponse: Decodable {
    let success: Bool
}

struct VerifyOTPResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AppUser?
    let needsProfile: Bool

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
        case needsProfile = "needs_profile"
    }
}

struct CreateProfileRequest: Encodable {
    let firstName: String
    let lastName: String
    let instagramHandle: String?
    let phoneNumber: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case instagramHandle = "instagram_handle"
        case phoneNumber = "phone_number"
    }
}

struct UpdateProfileRequest: Encodable {
    let firstName: String
    let lastName: String
    let instagramHandle: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case instagramHandle = "instagram_handle"
    }
}

struct RegisterPushTokenRequest: Encodable {
    let pushToken: String

    enum CodingKeys: String, CodingKey {
        case pushToken = "push_token"
    }
}

// MARK: - Auth Service

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: AppUser? {
        didSet { APIClient.shared.currentUserName = currentUser?.resolvedDisplayName }
    }
    @Published var isAuthenticated = false
    @Published var isInitializing = true
    @Published var needsProfile = false

    private let api = APIClient.shared
    private let coordinator = SessionCoordinator.shared
    @Published var recoveryError: String?
    @Published var isRecovering = false
    private var invalidationObserver: NSObjectProtocol?

    init() {
        coordinator.onTokenChange = { token in
            let generation = SessionCoordinator.shared.generation
            Task {
                guard generation == SessionCoordinator.shared.generation else { return }
                if let token {
                    await SupabaseManager.shared.client.realtimeV2.setAuth(token)
                } else {
                    await SupabaseManager.shared.client.removeAllChannels()
                }
            }
        }
        invalidationObserver = NotificationCenter.default.addObserver(
            forName: .sessionRequiresSignIn, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard !SessionCoordinator.shared.hasCredentials else { return }
                self?.clearSessionCaches()
                self?.currentUser = nil
                self?.isAuthenticated = false
                self?.needsProfile = false
                self?.recoveryError = nil
            }
        }
    }

    // MARK: - Initialize / reconnect

    func initialize() async {
        guard !isRecovering else { return }
        isRecovering = true
        defer { isInitializing = false; isRecovering = false }
        do {
            try coordinator.restore()
            guard coordinator.hasCredentials else { return }
            if let cached = coordinator.cachedProfile {
                currentUser = cached
                isAuthenticated = true
            }
            let generation = coordinator.generation
            do {
                let user: AppUser = try await api.get("/profiles/me")
                guard generation == coordinator.generation else { return }
                try coordinator.saveProfile(user)
                currentUser = user
                isAuthenticated = true
                needsProfile = false
                recoveryError = nil
            } catch APIError.httpError(let status, _) where status == 404 {
                guard generation == coordinator.generation else { return }
                needsProfile = true
                isAuthenticated = false
                recoveryError = nil
            }
        } catch SessionError.signInRequired {
            currentUser = nil
            isAuthenticated = false
            recoveryError = nil
        } catch SessionError.accountChanged {
            // A sign-out/new sign-in owns the newer state.
        } catch {
            // Log only error category/codes, never token payloads or provider bodies.
            let diagnostic = error as NSError
            Logger(subsystem: "com.wewere.app", category: "SessionRecovery").error("Recovery failed: domain=\(diagnostic.domain, privacy: .public) code=\(diagnostic.code)")
            if case SessionError.keychain(let status) = error {
                Logger(subsystem: "com.wewere.app", category: "SessionRecovery").error("Keychain status=\(status)")
            }
            recoveryError = "Unable to restore your session right now. Your saved sign-in is safe."
        }
    }

    private func accept(_ response: VerifyOTPResponse) async throws {
        clearSessionCaches()
        try coordinator.install(accessToken: response.accessToken, refreshToken: response.refreshToken, profile: response.user)
        recoveryError = nil
        if let user = response.user {
            currentUser = user
            isAuthenticated = true
            needsProfile = false
        } else if response.needsProfile {
            currentUser = nil
            needsProfile = true
            isAuthenticated = false
        } else {
            await initialize()
        }
    }

    // MARK: - Test Login (dev only)

    #if DEBUG && STAGING
    func testLogin(testId: String) async throws {
        struct TestLoginRequest: Encodable {
            let testId: String
            let firstName: String
            let lastName: String
            enum CodingKeys: String, CodingKey {
                case testId = "test_id"
                case firstName = "first_name"
                case lastName = "last_name"
            }
        }

        let generation = coordinator.generation
        let response: VerifyOTPResponse = try await api.post(
            "/auth/test-login",
            body: TestLoginRequest(testId: testId, firstName: "Test", lastName: "User"),
            requiresAuth: false
        )

        guard generation == coordinator.generation else { throw SessionError.accountChanged }
        try await accept(response)
    }
    #endif

    // MARK: - Phone OTP (via backend)

    func sendOTP(phoneNumber: String) async throws {
        struct SendOTPRequest: Encodable {
            let phoneNumber: String
            enum CodingKeys: String, CodingKey {
                case phoneNumber = "phone_number"
            }
        }

        let _: SendOTPResponse = try await api.post(
            "/auth/send-otp",
            body: SendOTPRequest(phoneNumber: phoneNumber),
            requiresAuth: false
        )
    }

    func verifyOTP(phoneNumber: String, code: String) async throws {
        struct VerifyOTPRequest: Encodable {
            let phoneNumber: String
            let code: String
            enum CodingKeys: String, CodingKey {
                case phoneNumber = "phone_number"
                case code
            }
        }

        let generation = coordinator.generation
        let response: VerifyOTPResponse = try await api.post(
            "/auth/verify-otp",
            body: VerifyOTPRequest(phoneNumber: phoneNumber, code: code),
            requiresAuth: false
        )

        guard generation == coordinator.generation else { throw SessionError.accountChanged }
        try await accept(response)
    }

    // MARK: - Profile Creation

    func createProfile(firstName: String, lastName: String, instagramHandle: String?, phoneNumber: String) async throws {
        let request = CreateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            instagramHandle: instagramHandle,
            phoneNumber: phoneNumber
        )

        let user: AppUser = try await api.post("/auth/create-profile", body: request)

        try coordinator.saveProfile(user)
        currentUser = user
        needsProfile = false
        isAuthenticated = true
    }

    // MARK: - Profile Update

    func updateDisplayName(_ name: String) async throws {
        guard currentUser != nil else { throw AuthError.noSession }

        let parts = name.split(separator: " ", maxSplits: 1)
        let firstName = String(parts.first ?? "")
        let lastName = parts.count > 1 ? String(parts[1]) : ""

        let request = UpdateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            instagramHandle: currentUser?.instagramHandle
        )

        let updatedUser: AppUser = try await api.put("/profiles/me", body: request)
        try coordinator.saveProfile(updatedUser)
        currentUser = updatedUser
    }

    func updateProfile(firstName: String, lastName: String, instagramHandle: String?) async throws {
        guard currentUser != nil else { throw AuthError.noSession }

        let request = UpdateProfileRequest(
            firstName: firstName,
            lastName: lastName,
            instagramHandle: instagramHandle
        )

        let updatedUser: AppUser = try await api.put("/profiles/me", body: request)
        try coordinator.saveProfile(updatedUser)
        currentUser = updatedUser
    }

    func registerPushToken(_ token: String) async throws {
        guard currentUser != nil else { throw AuthError.noSession }

        let request = RegisterPushTokenRequest(pushToken: token)
        let _: EmptyResponse = try await api.put("/profiles/me/push-token", body: request)
        currentUser?.pushToken = token
    }

    // MARK: - Sign Out

    private func clearSessionCaches() {
        AlbumViewModel.clearSessionCache()
        EventDetailViewModel.clearSessionCache()
        PhotoStackViewModel.clearSessionCache()
        URLCache.shared.removeAllCachedResponses()
    }

    func signOut() async throws {
        try await coordinator.signOut()
        clearSessionCaches()
        currentUser = nil
        isAuthenticated = false
        needsProfile = false
        recoveryError = nil
    }
}

// MARK: - Errors

extension AuthService {
    enum AuthError: LocalizedError {
        case noSession
        case otpSendFailed(String)
        case otpVerifyFailed(String)

        var errorDescription: String? {
            switch self {
            case .noSession:
                return "No active session found."
            case .otpSendFailed(let detail):
                return "Failed to send verification code: \(detail)"
            case .otpVerifyFailed(let detail):
                return "Verification failed: \(detail)"
            }
        }
    }
}
