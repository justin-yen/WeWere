import Foundation
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
    private let tokenKey = "wewere_access_token"
    private let refreshTokenKey = "wewere_refresh_token"

    // Keep SupabaseManager for realtime subscriptions only
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Initialize

    func initialize() async {
        defer { isInitializing = false }

        // Try to restore saved token
        guard let savedToken = UserDefaults.standard.string(forKey: tokenKey) else {
            print("No saved token found")
            return
        }

        api.setToken(savedToken)

        // Verify token is still valid by fetching profile
        do {
            let user: AppUser = try await api.get("/profiles/me")
            currentUser = user
            isAuthenticated = true

            // Also restore Supabase session for realtime
            await restoreSupabaseSession()
        } catch {
            print("Saved token invalid: \(error.localizedDescription)")
            api.clearToken()
            UserDefaults.standard.removeObject(forKey: tokenKey)
            UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        }
    }

    // MARK: - Test Login (dev only)

    #if DEBUG
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

        let response: VerifyOTPResponse = try await api.post(
            "/auth/test-login",
            body: TestLoginRequest(testId: testId, firstName: "Test", lastName: "User"),
            requiresAuth: false
        )

        api.setToken(response.accessToken)
        UserDefaults.standard.set(response.accessToken, forKey: tokenKey)
        UserDefaults.standard.set(response.refreshToken, forKey: refreshTokenKey)

        await setSupabaseSession(accessToken: response.accessToken, refreshToken: response.refreshToken)

        if let user = response.user {
            currentUser = user
            isAuthenticated = true
            needsProfile = false
        } else {
            needsProfile = true
        }
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

        let response: VerifyOTPResponse = try await api.post(
            "/auth/verify-otp",
            body: VerifyOTPRequest(phoneNumber: phoneNumber, code: code),
            requiresAuth: false
        )

        print("DEBUG verify-otp response: needsProfile=\(response.needsProfile), user=\(response.user != nil)")

        // Store tokens
        api.setToken(response.accessToken)
        UserDefaults.standard.set(response.accessToken, forKey: tokenKey)
        UserDefaults.standard.set(response.refreshToken, forKey: refreshTokenKey)

        // Set Supabase session for realtime subscriptions
        await setSupabaseSession(accessToken: response.accessToken, refreshToken: response.refreshToken)

        if let user = response.user {
            print("DEBUG: got user profile: \(user.resolvedDisplayName)")
            currentUser = user
            isAuthenticated = true
            needsProfile = false
        } else if response.needsProfile {
            print("DEBUG: needs profile setup")
            needsProfile = true
        } else {
            // Backend says no profile needed but didn't return user object
            // Try fetching the profile directly
            print("DEBUG: no user in response, fetching profile...")
            do {
                let profile: AppUser = try await api.get("/profiles/me")
                currentUser = profile
                isAuthenticated = true
                needsProfile = false
                print("DEBUG: fetched profile: \(profile.resolvedDisplayName)")
            } catch {
                print("DEBUG: profile fetch failed: \(error)")
                needsProfile = true
            }
        }
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
        currentUser = updatedUser
    }

    func registerPushToken(_ token: String) async throws {
        guard currentUser != nil else { throw AuthError.noSession }

        let request = RegisterPushTokenRequest(pushToken: token)
        let _: EmptyResponse = try await api.put("/profiles/me/push-token", body: request)
        currentUser?.pushToken = token
    }

    // MARK: - Sign Out

    func signOut() async throws {
        api.clearToken()
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)

        try? await client.auth.signOut()

        currentUser = nil
        isAuthenticated = false
        needsProfile = false
    }

    // MARK: - Supabase Session (for realtime only)

    private func setSupabaseSession(accessToken: String, refreshToken: String) async {
        do {
            try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
        } catch {
            print("Failed to set Supabase session for realtime: \(error)")
        }
    }

    private func restoreSupabaseSession() async {
        guard let accessToken = UserDefaults.standard.string(forKey: tokenKey),
              let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else { return }
        await setSupabaseSession(accessToken: accessToken, refreshToken: refreshToken)
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
