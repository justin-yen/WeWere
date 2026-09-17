import Foundation
import Security
import OSLog

struct SessionCredentials: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let accountID: UUID
    var expiresAt: Date

    // Claims here are scheduling/identity metadata only. Authorization is always
    // checked by the backend or Supabase, never by this unverified decode.
    init(accessToken: String, refreshToken: String) throws {
        let pieces = accessToken.split(separator: ".")
        guard pieces.count == 3, !refreshToken.isEmpty else { throw SessionError.invalidResponse }
        var payload = String(pieces[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let subject = claims["sub"] as? String, let id = UUID(uuidString: subject),
              let expiry = claims["exp"] as? Double else { throw SessionError.invalidResponse }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountID = id
        self.expiresAt = Date(timeIntervalSince1970: expiry)
    }
}

struct StoredSession: Codable {
    var credentials: SessionCredentials?
    var profile: AppUser?
    var lastAccountID: UUID?
}

enum SessionError: LocalizedError {
    case signInRequired, accountChanged, invalidResponse, temporarilyUnavailable
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .signInRequired: return "Please sign in again to resume."
        case .accountChanged: return "The signed-in account changed. Please try again."
        case .invalidResponse: return "Unable to restore your session. Please try again."
        case .temporarilyUnavailable: return "Unable to connect. Your saved session is safe; please try again."
        case .keychain: return "Unable to access your saved session. Unlock your device and try again."
        }
    }
}

protocol SessionStore {
    func load() throws -> StoredSession?
    func save(_ session: StoredSession) throws
}

struct KeychainSessionStore: SessionStore {
    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: AppEnvironment.keychainService,
        kSecAttrAccount as String: "current-session"
    ]

    func load() throws -> StoredSession? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SessionError.keychain(status) }
        return try JSONDecoder().decode(StoredSession.self, from: data)
    }

    func save(_ session: StoredSession) throws {
        let data = try JSONEncoder().encode(session)
        let values: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SessionError.keychain(status) }
    }
}

protocol SessionTransport {
    func refresh(_ credentials: SessionCredentials) async throws -> SessionCredentials
    func revoke(_ accessToken: String) async
}

struct SupabaseSessionTransport: SessionTransport {
    var session: URLSession = AppNetwork.session

    func refresh(_ credentials: SessionCredentials) async throws -> SessionCredentials {
        var request = URLRequest(url: URL(string: AppEnvironment.supabaseURL + "/auth/v1/token?grant_type=refresh_token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": credentials.refreshToken])
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw SessionError.invalidResponse }
        guard (200...299).contains(response.statusCode) else {
            struct Failure: Decodable {
                var code: String?
                var error_code: String?
                var error: String?
                enum CodingKeys: String, CodingKey { case code, error_code, error }
                init(from decoder: Decoder) throws {
                    let values = try decoder.container(keyedBy: CodingKeys.self)
                    // Supabase also sends a numeric HTTP `code`. It must not
                    // prevent decoding the separate machine-readable error_code.
                    code = try? values.decode(String.self, forKey: .code)
                    error_code = try? values.decode(String.self, forKey: .error_code)
                    error = try? values.decode(String.self, forKey: .error)
                }
            }
            let failure = try? JSONDecoder().decode(Failure.self, from: data)
            let code = failure?.error_code ?? failure?.code ?? failure?.error
            Logger(subsystem: "com.wewere.app", category: "SessionRecovery").error("Refresh rejected: HTTP \(response.statusCode), code=\(code ?? "unknown", privacy: .public)")
            let terminal = ["refresh_token_not_found", "refresh_token_already_used", "session_not_found", "session_expired", "user_not_found", "user_banned", "invalid_grant"]
            if [400, 401, 403].contains(response.statusCode), let code, terminal.contains(code) {
                throw SessionError.signInRequired
            }
            // Unknown 4xx, rate limits, network failures and 5xx must not erase credentials.
            throw SessionError.temporarilyUnavailable
        }
        struct Tokens: Decodable { let access_token: String; let refresh_token: String }
        let tokens = try JSONDecoder().decode(Tokens.self, from: data)
        return try SessionCredentials(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
    }

    func revoke(_ accessToken: String) async {
        var request = URLRequest(url: URL(string: AppEnvironment.supabaseURL + "/auth/v1/logout?scope=local")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(AppEnvironment.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }
}

extension Notification.Name {
    static let sessionRequiresSignIn = Notification.Name("sessionRequiresSignIn")
}

/// Sole owner of tokens for both FastAPI and Supabase requests. All state transitions
/// are serialized; suspended requests must retain the same session generation.
@MainActor
final class SessionCoordinator {
    static let shared = SessionCoordinator()
    private let store: SessionStore
    private let transport: SessionTransport
    private let defaults: UserDefaults
    private var stored = StoredSession()
    private var restored = false
    private var refreshTask: Task<String, Error>?
    private(set) var generation = UUID()
    var onTokenChange: ((String?) -> Void)?
    var accountID: UUID? { stored.credentials?.accountID }
    var cachedProfile: AppUser? { stored.profile }
    var hasCredentials: Bool { stored.credentials != nil }

    init(store: SessionStore = KeychainSessionStore(), transport: SessionTransport = SupabaseSessionTransport(), defaults: UserDefaults = .standard) {
        self.store = store
        self.transport = transport
        self.defaults = defaults
    }

    func restore() throws {
        guard !restored else { return }
        if let saved = try store.load() {
            stored = saved
        } else if let access = defaults.string(forKey: "wewere_access_token"),
                  let refresh = defaults.string(forKey: "wewere_refresh_token") {
            stored = StoredSession(credentials: try SessionCredentials(accessToken: access, refreshToken: refresh))
            try store.save(stored)
        }
        // Remove legacy plaintext only after the Keychain write succeeds.
        defaults.removeObject(forKey: "wewere_access_token")
        defaults.removeObject(forKey: "wewere_refresh_token")
        restored = true
    }

    func install(accessToken: String, refreshToken: String, profile: AppUser?) throws {
        let credentials = try SessionCredentials(accessToken: accessToken, refreshToken: refreshToken)
        let replacement = StoredSession(credentials: credentials, profile: profile, lastAccountID: credentials.accountID)
        try store.save(replacement)
        generation = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        stored = replacement
        restored = true
        defaults.removeObject(forKey: "wewere_access_token")
        defaults.removeObject(forKey: "wewere_refresh_token")
        onTokenChange?(credentials.accessToken)
    }

    func saveProfile(_ profile: AppUser) throws {
        guard hasCredentials else { throw SessionError.signInRequired }
        var replacement = stored
        replacement.profile = profile
        try store.save(replacement)
        stored = replacement
    }

    func accessToken(rejectedToken: String? = nil) async throws -> String {
        try restore()
        guard let credentials = stored.credentials else { throw SessionError.signInRequired }
        // Persist a rotated token before starting any further refresh, including
        // when a prior Keychain write failed transiently.
        try store.save(stored)
        if let refreshTask { return try await refreshTask.value }
        if let rejectedToken, rejectedToken != credentials.accessToken {
            return credentials.accessToken
        }
        if rejectedToken == nil && credentials.expiresAt.timeIntervalSinceNow > 60 {
            return credentials.accessToken
        }
        let expectedGeneration = generation
        let task = Task<String, Error> {
            defer { if self.generation == expectedGeneration { self.refreshTask = nil } }
            do {
                let refreshed = try await self.transport.refresh(credentials)
                guard self.generation == expectedGeneration else { throw SessionError.accountChanged }
                guard refreshed.accountID == credentials.accountID else { throw SessionError.invalidResponse }
                self.stored.credentials = refreshed
                try self.store.save(self.stored)
                self.onTokenChange?(refreshed.accessToken)
                return refreshed.accessToken
            } catch SessionError.signInRequired {
                guard self.generation == expectedGeneration else { throw SessionError.accountChanged }
                // Preserve the account identifier and any pending work, but stop authenticated requests.
                self.stored.credentials = nil
                self.stored.profile = nil
                self.stored.lastAccountID = credentials.accountID
                self.generation = UUID()
                self.refreshTask = nil
                self.onTokenChange?(nil)
                NotificationCenter.default.post(name: .sessionRequiresSignIn, object: nil)
                try self.store.save(self.stored)
                throw SessionError.signInRequired
            } catch {
                guard self.generation == expectedGeneration else { throw SessionError.accountChanged }
                throw error
            }
        }
        refreshTask = task
        return try await task.value
    }

    func signOut() async throws {
        let token = stored.credentials?.accessToken
        let replacement = StoredSession(lastAccountID: stored.credentials?.accountID ?? stored.lastAccountID)
        try store.save(replacement)
        generation = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        stored = replacement
        onTokenChange?(nil)
        restored = true
        defaults.removeObject(forKey: "wewere_access_token")
        defaults.removeObject(forKey: "wewere_refresh_token")
        if let token { Task { await transport.revoke(token) } }
    }

    #if DEBUG && STAGING && targetEnvironment(simulator)
    func prepareValidation(expired: Bool = false, clearProfile: Bool = false) throws {
        try restore()
        guard hasCredentials else { throw SessionError.signInRequired }
        if expired { stored.credentials?.expiresAt = .distantPast }
        if clearProfile { stored.profile = nil }
        try store.save(stored)
    }
    #endif
}
