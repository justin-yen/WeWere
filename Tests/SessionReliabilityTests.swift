import Foundation

final class MemoryStore: SessionStore {
    var value: StoredSession?
    var failWrites = false
    func load() throws -> StoredSession? { value }
    func save(_ session: StoredSession) throws {
        if failWrites { throw SessionError.keychain(-1) }
        value = session
    }
}

final class FakeTransport: SessionTransport {
    var calls = 0
    var failure: Error?
    var response: SessionCredentials!
    func refresh(_ credentials: SessionCredentials) async throws -> SessionCredentials {
        calls += 1
        // Deliberately ignores cancellation to simulate a late network response.
        try? await Task.sleep(nanoseconds: 30_000_000)
        if let failure { throw failure }
        return response
    }
    func revoke(_ accessToken: String) async {}
}

final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

struct CheckFailure: Error { let message: String }
func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(message: message) }
}
func credentials(_ id: UUID, expired: Bool = false, suffix: String = "one") throws -> SessionCredentials {
    let data = try JSONSerialization.data(withJSONObject: ["sub": id.uuidString, "exp": Date().timeIntervalSince1970 + (expired ? -60 : 3600)])
    let part = data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    return try SessionCredentials(accessToken: "header.\(part).\(suffix)", refreshToken: "refresh-\(suffix)")
}

@MainActor
@main
struct ReliabilityTests {
    static func main() async {
        var failures = 0
        let tests: [(String, @MainActor () async throws -> Void)] = [
            ("concurrent requests share a refresh", concurrentRefresh),
            ("network failure retains credentials and recovers", networkRecovery),
            ("terminal refresh error pauses account without removing work", invalidRefresh),
            ("late refresh cannot resurrect a signed-out session", signOutRace),
            ("late refresh cannot replace another account", accountSwitchRace),
            ("Keychain migration is lossless on failure", migration),
            ("sign-out before restore retires legacy credentials", signOutBeforeRestore),
            ("rotated token survives transient persistence error in memory", persistenceFailure),
            ("API 401 retries once with refreshed token and original body", apiRetry),
            ("API 5xx never retries mutations", apiNoRetry),
            ("API second 401 does not loop", apiRetryLimit),
            ("refresh transport distinguishes outages from revoked sessions", refreshClassification),
            ("mismatched refresh identity is rejected", wrongIdentity)
        ]
        for (name, run) in tests {
            do { try await run(); print("PASS: \(name)") }
            catch { failures += 1; print("FAIL: \(name): \(error)") }
        }
        print("\(tests.count - failures)/\(tests.count) reliability checks passed")
        if failures > 0 { exit(1) }
    }

    static func fixture(expired: Bool = true) throws -> (SessionCoordinator, MemoryStore, FakeTransport, SessionCredentials) {
        let store = MemoryStore(), transport = FakeTransport()
        let initial = try credentials(UUID(), expired: expired)
        store.value = StoredSession(credentials: initial)
        transport.response = try credentials(initial.accountID, suffix: "two")
        let defaults = UserDefaults(suiteName: "wewere-tests-\(UUID())")!
        let coordinator = SessionCoordinator(store: store, transport: transport, defaults: defaults)
        try coordinator.restore()
        return (coordinator, store, transport, initial)
    }
    static func concurrentRefresh() async throws {
        let (c, s, t, _) = try fixture()
        let tasks = (0..<10).map { _ in Task { try await c.accessToken() } }
        for task in tasks { let token = try await task.value; try check(token == t.response.accessToken, "wrong token") }
        try check(t.calls == 1, "duplicate refresh")
        try check(s.value?.credentials == t.response, "rotation not persisted")
    }
    static func networkRecovery() async throws {
        let (c, s, t, original) = try fixture()
        t.failure = URLError(.notConnectedToInternet)
        do { _ = try await c.accessToken(); throw CheckFailure(message: "expected offline") } catch is URLError {}
        try check(s.value?.credentials == original && c.hasCredentials, "credentials discarded")
        t.failure = nil
        _ = try await c.accessToken()
        try check(t.calls == 2, "retry did not recover")
    }
    static func invalidRefresh() async throws {
        let (c, s, t, original) = try fixture()
        t.failure = SessionError.signInRequired
        do { _ = try await c.accessToken(); throw CheckFailure(message: "expected sign-in") } catch SessionError.signInRequired {}
        try check(!c.hasCredentials && s.value?.lastAccountID == original.accountID, "invalid state")
    }
    static func signOutRace() async throws {
        let (c, s, _, _) = try fixture()
        let refresh = Task { try await c.accessToken() }
        await Task.yield()
        try await c.signOut()
        do { _ = try await refresh.value; throw CheckFailure(message: "late success") } catch SessionError.accountChanged {} catch SessionError.signInRequired {}
        try check(s.value?.credentials == nil, "session resurrected")
    }
    static func accountSwitchRace() async throws {
        let (c, s, _, _) = try fixture()
        let refresh = Task { try await c.accessToken() }
        await Task.yield()
        let next = try credentials(UUID())
        try c.install(accessToken: next.accessToken, refreshToken: next.refreshToken, profile: nil)
        do { _ = try await refresh.value; throw CheckFailure(message: "late success") } catch SessionError.accountChanged {}
        try check(s.value?.credentials == next, "account overwritten")
    }
    static func migration() async throws {
        let domain = "wewere-migration-\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let original = try credentials(UUID())
        defaults.set(original.accessToken, forKey: "wewere_access_token")
        defaults.set(original.refreshToken, forKey: "wewere_refresh_token")
        let store = MemoryStore(); store.failWrites = true
        let c = SessionCoordinator(store: store, transport: FakeTransport(), defaults: defaults)
        do { try c.restore(); throw CheckFailure(message: "write should fail") } catch SessionError.keychain {}
        try check(defaults.string(forKey: "wewere_refresh_token") != nil, "legacy token lost")
        store.failWrites = false
        try c.restore()
        try check(defaults.string(forKey: "wewere_access_token") == nil && store.value?.credentials == original, "migration incomplete")
    }
    static func persistenceFailure() async throws {
        let (c, s, t, _) = try fixture()
        let refresh = Task { try await c.accessToken() }
        try await Task.sleep(nanoseconds: 5_000_000)
        s.failWrites = true
        do { _ = try await refresh.value; throw CheckFailure(message: "write should fail") } catch SessionError.keychain {}
        s.failWrites = false
        let token = try await c.accessToken()
        try check(t.calls == 1 && token == t.response.accessToken && s.value?.credentials == t.response, "rotation lost")
    }
    static func httpSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }
    static func apiRetry() async throws {
        let (c, _, t, old) = try fixture(expired: false)
        let session = httpSession(); defer { session.invalidateAndCancel() }
        var calls = 0; var firstBody: Data?
        StubProtocol.handler = { req in
            calls += 1
            if calls == 1 { firstBody = req.httpBody; return (401, Data()) }
            try check(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(t.response.accessToken)", "not refreshed")
            try check(req.httpBody == firstBody, "mutation changed")
            return (200, Data())
        }
        let api = APIClient(baseURL: "https://api.invalid", session: session, coordinator: c)
        let _: EmptyResponse = try await api.post("/test", body: ["example": "payload"])
        try check(calls == 2 && t.calls == 1 && old != t.response, "unexpected retry count")
    }
    static func apiNoRetry() async throws {
        let (c, s, t, old) = try fixture(expired: false)
        let session = httpSession(); defer { session.invalidateAndCancel() }
        var calls = 0
        StubProtocol.handler = { _ in calls += 1; return (503, Data()) }
        let api = APIClient(baseURL: "https://api.invalid", session: session, coordinator: c)
        do { let _: EmptyResponse = try await api.post("/test", body: ["x": "y"]); throw CheckFailure(message: "expected 503") } catch APIError.httpError(let status, _) { try check(status == 503, "wrong status") }
        try check(calls == 1 && t.calls == 0 && s.value?.credentials == old, "unsafe replay or credential loss")
    }
    static func apiRetryLimit() async throws {
        let (c, _, t, _) = try fixture(expired: false)
        let session = httpSession(); defer { session.invalidateAndCancel() }
        var calls = 0
        StubProtocol.handler = { _ in calls += 1; return (401, Data()) }
        let api = APIClient(baseURL: "https://api.invalid", session: session, coordinator: c)
        do { let _: EmptyResponse = try await api.get("/test"); throw CheckFailure(message: "expected 401") } catch APIError.httpError(let status, _) { try check(status == 401, "wrong status") }
        try check(calls == 2 && t.calls == 1 && c.hasCredentials, "retry loop or credentials erased")
    }
    static func refreshClassification() async throws {
        let session = httpSession(); defer { session.invalidateAndCancel() }
        let transport = SupabaseSessionTransport(session: session)
        let old = try credentials(UUID(), expired: true)
        for status in [429, 500, 503, 400, 401] {
            StubProtocol.handler = { _ in (status, Data("{}".utf8)) }
            do { _ = try await transport.refresh(old); throw CheckFailure(message: "expected transient") } catch SessionError.temporarilyUnavailable {}
        }
        StubProtocol.handler = { _ in (400, Data("{\"error_code\":\"refresh_token_not_found\"}".utf8)) }
        do { _ = try await transport.refresh(old); throw CheckFailure(message: "expected revoked") } catch SessionError.signInRequired {}
        StubProtocol.handler = { _ in (400, Data("{\"code\":400,\"error_code\":\"refresh_token_not_found\",\"msg\":\"Invalid Refresh Token\"}".utf8)) }
        do { _ = try await transport.refresh(old); throw CheckFailure(message: "numeric code masked revoked session") } catch SessionError.signInRequired {}
    }
    static func wrongIdentity() async throws {
        let (c, s, t, old) = try fixture()
        t.response = try credentials(UUID())
        do { _ = try await c.accessToken(); throw CheckFailure(message: "accepted wrong identity") } catch SessionError.invalidResponse {}
        try check(s.value?.credentials == old, "changed identity")
    }
    static func signOutBeforeRestore() async throws {
        let store = MemoryStore(), transport = FakeTransport()
        let old = try credentials(UUID())
        let defaults = UserDefaults(suiteName: "wewere-tests-\(UUID())")!
        defaults.set(old.accessToken, forKey: "wewere_access_token")
        defaults.set(old.refreshToken, forKey: "wewere_refresh_token")
        let coordinator = SessionCoordinator(store: store, transport: transport, defaults: defaults)
        try await coordinator.signOut()
        try coordinator.restore()
        try check(!coordinator.hasCredentials, "restored signed-out credentials")
        try check(defaults.string(forKey: "wewere_access_token") == nil, "legacy access token remained")
        try check(defaults.string(forKey: "wewere_refresh_token") == nil, "legacy refresh token remained")
    }
}
