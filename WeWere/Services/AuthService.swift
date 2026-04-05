import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var isInitializing = true
    @Published var needsProfile = false

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // Twilio Verify credentials (called directly, bypassing Supabase phone auth)
    private let twilioAccountSID = Secrets.twilioAccountSID
    private let twilioAuthToken = Secrets.twilioAuthToken
    private let twilioVerifySID = Secrets.twilioVerifySID

    // MARK: - Initialize

    func initialize() async {
        defer { isInitializing = false }

        do {
            let session = try await client.auth.session
            print("Restored existing session for user: \(session.user.id)")
            try await fetchCurrentUser()
        } catch {
            print("No existing session: \(error.localizedDescription)")
        }
    }

    // MARK: - Phone OTP (via Twilio Verify directly)

    func sendOTP(phoneNumber: String) async throws {
        let url = URL(string: "https://verify.twilio.com/v2/Services/\(twilioVerifySID)/Verifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Basic auth
        let credentials = "\(twilioAccountSID):\(twilioAuthToken)"
        let base64 = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedPhone = phoneNumber.replacingOccurrences(of: "+", with: "%2B")
        let body = "To=\(encodedPhone)&Channel=sms"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("Twilio send OTP response (\(httpResponse?.statusCode ?? 0)): \(responseText)")

        guard httpResponse?.statusCode == 201 else {
            throw AuthError.otpSendFailed(responseText)
        }
    }

    func verifyOTP(phoneNumber: String, code: String) async throws {
        // Step 1: Verify with Twilio
        let url = URL(string: "https://verify.twilio.com/v2/Services/\(twilioVerifySID)/VerificationCheck")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let credentials = "\(twilioAccountSID):\(twilioAuthToken)"
        let base64 = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedPhone = phoneNumber.replacingOccurrences(of: "+", with: "%2B")
        let body = "To=\(encodedPhone)&Code=\(code)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let responseText = String(data: data, encoding: .utf8) ?? ""

        print("Twilio verify OTP response (\(httpResponse?.statusCode ?? 0)): \(responseText)")

        guard httpResponse?.statusCode == 200 else {
            throw AuthError.otpVerifyFailed(responseText)
        }

        // Parse the status
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String,
           status != "approved" {
            throw AuthError.otpVerifyFailed("Verification status: \(status)")
        }

        // Step 2: Sign into Supabase with email+password using phone as identifier
        // This creates a Supabase session so RLS works
        let email = "\(phoneNumber.replacingOccurrences(of: "+", with: ""))@wewere.phone"
        let password = "phone_\(phoneNumber)_verified"

        do {
            // Try signing in first (returning user)
            try await client.auth.signIn(email: email, password: password)
        } catch {
            // New user -- sign up
            try await client.auth.signUp(email: email, password: password)
        }

        // Step 3: Check if user profile exists
        guard let authUser = client.auth.currentUser else {
            throw AuthError.noSession
        }

        do {
            let users: [AppUser] = try await client
                .from("users")
                .select()
                .eq("auth_id", value: authUser.id.uuidString)
                .execute()
                .value

            if let existingUser = users.first {
                currentUser = existingUser
                isAuthenticated = true
                needsProfile = false
            } else {
                needsProfile = true
            }
        } catch {
            needsProfile = true
        }
    }

    // MARK: - Profile Creation

    func createProfile(firstName: String, lastName: String, instagramHandle: String?, phoneNumber: String) async throws {
        guard let authUser = client.auth.currentUser else {
            throw AuthError.noSession
        }

        let displayName = "\(firstName) \(lastName)"
        let now = Date()

        let user = AppUser(
            id: UUID(),
            authId: authUser.id,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            instagramHandle: instagramHandle,
            phoneNumber: phoneNumber,
            avatarUrl: nil,
            pushToken: nil,
            createdAt: now
        )

        let saved: AppUser = try await client
            .from("users")
            .upsert(user, onConflict: "auth_id")
            .select()
            .single()
            .execute()
            .value

        currentUser = saved
        needsProfile = false
        isAuthenticated = true
    }

    // MARK: - Profile Update

    func updateDisplayName(_ name: String) async throws {
        guard let userId = currentUser?.id else { throw AuthError.noSession }

        try await client
            .from("users")
            .update(["display_name": name])
            .eq("id", value: userId.uuidString)
            .execute()

        currentUser?.displayName = name
    }

    func updateProfile(firstName: String, lastName: String, instagramHandle: String?) async throws {
        guard let userId = currentUser?.id else { throw AuthError.noSession }

        let displayName = "\(firstName) \(lastName)"
        try await client
            .from("users")
            .update([
                "first_name": firstName,
                "last_name": lastName,
                "display_name": displayName,
                "instagram_handle": instagramHandle ?? ""
            ])
            .eq("id", value: userId.uuidString)
            .execute()

        currentUser?.firstName = firstName
        currentUser?.lastName = lastName
        currentUser?.displayName = displayName
        currentUser?.instagramHandle = instagramHandle
    }

    func registerPushToken(_ token: String) async throws {
        guard let userId = currentUser?.id else { throw AuthError.noSession }

        try await client
            .from("users")
            .update(["push_token": token])
            .eq("id", value: userId.uuidString)
            .execute()

        currentUser?.pushToken = token
    }

    // MARK: - Sign Out

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
        isAuthenticated = false
        needsProfile = false
    }

    // MARK: - Fetch

    func fetchCurrentUser() async throws {
        guard let authUser = client.auth.currentUser else {
            throw AuthError.noSession
        }

        let user: AppUser = try await client
            .from("users")
            .select()
            .eq("auth_id", value: authUser.id.uuidString)
            .single()
            .execute()
            .value

        currentUser = user
        isAuthenticated = true
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
