#if DEBUG && STAGING && targetEnvironment(simulator)
import SwiftUI

/// Simulator-only validation controls. Never compiled into production or devices.
struct SessionValidationView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var mode = StagingFaultProtocol.mode
    @State private var result = "Ready"
    @State private var running = false
    private let coordinator = SessionCoordinator.shared

    var body: some View {
        NavigationStack {
            List {
                Section("API/auth fault injection") {
                    Text("Live calls use staging. Faults affect this app only and survive relaunch.")
                    ForEach(["live", "offline", "503", "revoked"], id: \.self) { value in
                        Button("Network: \(value)\(mode == value ? " ✓" : "")") {
                            mode = value; StagingFaultProtocol.mode = value
                            record("Network mode: \(value)")
                        }.disabled(running)
                    }
                }
                Section("Session") {
                    Text("Account: \(auth.currentUser?.resolvedDisplayName ?? "signed out")")
                    Text("Credentials: \(coordinator.hasCredentials ? "saved" : "none")")
                    Text("Recovery error: \(auth.recoveryError == nil ? "none" : "present")")
                    Button("Probe profile recovery") { perform { await auth.initialize(); try snapshot("Profile probe") } }
                    Button("Expire locally and probe") { perform {
                        try coordinator.prepareValidation(expired: true)
                        StagingFaultProtocol.resetCounts()
                        await auth.initialize()
                        try snapshot("Expired probe; refreshes=\(StagingFaultProtocol.refreshCount)")
                    } }
                    Button("Prepare uncached offline startup") { perform {
                        try coordinator.prepareValidation(expired: true, clearProfile: true)
                        mode = "offline"; StagingFaultProtocol.mode = mode
                        record("Prepared: credentials retained, cached profile removed, offline. Relaunch now.")
                    } }
                }.disabled(running)
                Section("Races using live staging") {
                    Button("Run 10 concurrent requests") { perform { try await concurrent() } }
                    Button("Sign out during refresh") { perform { try await race(switchAccount: false) } }
                    Button("Switch to TEST2 during refresh") { perform { try await race(switchAccount: true) } }
                }.disabled(running)
                Section("Result") { Text(result).textSelection(.enabled) }
            }
            .navigationTitle("Session validation")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !running else { return }
        running = true
        Task { @MainActor in
            defer { running = false }
            do { try await operation() }
            catch { record("FAIL: \(error.localizedDescription)") }
        }
    }
    private func snapshot(_ name: String) throws {
        let persisted = try KeychainSessionStore().load()
        record("\(name): memory=\(coordinator.hasCredentials), keychain=\(persisted?.credentials != nil), authenticated=\(auth.isAuthenticated), recoveryError=\(auth.recoveryError != nil)")
    }
    private func record(_ text: String) {
        result = text
        // Persist only test results, never tokens, phone numbers, or account IDs.
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("session-validation.txt")
        let previous = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        try? (previous + "\(Date().ISO8601Format()) \(text)\n").write(to: file, atomically: true, encoding: .utf8)
    }
    private func concurrent() async throws {
        mode = "live"; StagingFaultProtocol.mode = mode
        try coordinator.prepareValidation(expired: true)
        StagingFaultProtocol.resetCounts()
        let expected = coordinator.accountID
        let users = try await withThrowingTaskGroup(of: AppUser.self) { group in
            for _ in 0..<10 { group.addTask { try await APIClient.shared.get("/profiles/me") } }
            var users: [AppUser] = []
            for try await user in group { users.append(user) }
            return users
        }
        guard users.count == 10, Set(users.map(\.id)).count == 1,
              coordinator.accountID == expected, StagingFaultProtocol.refreshCount == 1 else {
            throw ValidationFailure(message: "Concurrent requests did not share one refresh")
        }
        record("PASS: 10 live profile requests; 1 live refresh; same account")
    }
    private func race(switchAccount: Bool) async throws {
        mode = "delayed"; StagingFaultProtocol.mode = mode
        defer { mode = "live"; StagingFaultProtocol.mode = "live" }
        try coordinator.prepareValidation(expired: true)
        StagingFaultProtocol.resetCounts()
        let previousID = coordinator.accountID
        let pending = Task { () -> Bool in
            do { let _: AppUser = try await APIClient.shared.get("/profiles/me"); return false }
            catch SessionError.accountChanged { return true }
            catch { return false }
        }
        for _ in 0..<100 {
            if StagingFaultProtocol.refreshCount > 0 { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard StagingFaultProtocol.refreshCount == 1 else {
            pending.cancel(); throw ValidationFailure(message: "Refresh did not start")
        }
        if switchAccount { try await auth.testLogin(testId: "test2") }
        else { try await auth.signOut() }
        let rejected = await pending.value
        // Also wait past the injected late-response interval.
        try await Task.sleep(nanoseconds: 3_500_000_000)
        let saved = try KeychainSessionStore().load()
        let correct = switchAccount
            ? (coordinator.accountID != nil && coordinator.accountID != previousID && auth.currentUser?.lastName.contains("TEST2") == true && saved?.credentials?.accountID == coordinator.accountID)
            : (!coordinator.hasCredentials && saved?.credentials == nil && !auth.isAuthenticated)
        guard rejected && correct else { throw ValidationFailure(message: "Old session survived the race") }
        record("PASS: \(switchAccount ? "switch to TEST2" : "sign out") during refresh; late request rejected; Keychain and UI retain correct state")
    }
}

private struct ValidationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
#endif
