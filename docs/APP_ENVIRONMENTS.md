# Switching app environments

```sh
./scripts/run.sh                    # staging by default
./scripts/run.sh --env staging
./scripts/run.sh --env production
```

Both apps can remain installed. Staging is named **WeWere Staging** and shows an orange STAGING badge. Production is **WeWere**. Flags such as `--sim`, `--device`, and `--build-only` work with either environment.

| Configuration | Staging | Production |
| --- | --- | --- |
| Xcode scheme | WeWere-Staging | WeWere |
| Build configuration | StagingDebug | Debug (Release for archive) |
| Bundle ID | com.wewere.app.staging | com.wewere.app |
| Railway API | api-staging-staging-62e9.up.railway.app | api-production-77f0.up.railway.app |
| Supabase project | rmehfwdzxyrsdpvwgozm | Existing Secrets.swift configuration |
| Keychain service | com.wewere.session.staging | com.wewere.session |
| Invite URL scheme | wewere-staging | wewere |

Different bundle IDs isolate UserDefaults, files, and caches; different Keychain services isolate credentials. Existing production sessions retain their original storage identifier. Each build selects API and Supabase together through `AppEnvironment`. Developer test-account login is compiled only into staging Debug builds. Production testing uses real accounts and data.

## Local configuration

Keep existing production credentials in gitignored `WeWere/Secrets.swift`. Staging needs gitignored `WeWere/StagingSecrets.swift`:

```swift
#if STAGING
enum StagingSecrets {
    static let supabaseAnonKey = "YOUR_STAGING_ANON_KEY"
}
#endif
```

Only the anonymous client key belongs here; never add service-role or internal backend keys. The current machine's staging file is configured. A fresh checkout requires restoring both local configuration files. The staging file compiles no credentials into production builds.

Use staging invite links only with staging. Universal-link entitlements and physical-device provisioning are separate from this simulator setup. WEW-16's completed outage/recovery walkthrough is recorded in `docs/WEW16_FINAL_VALIDATION.md`. Debug staging simulator builds expose a **Session tests** panel for controlled API/auth faults; its network mode persists across relaunch, so restore **live** after testing. These controls are excluded from production and physical-device builds.
