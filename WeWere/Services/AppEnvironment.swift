import Foundation

/// Compile-time pairing prevents mixing production sessions with staging services.
enum AppEnvironment {
    #if STAGING
    static let isStaging = true
    static let urlScheme = "wewere-staging"
    static let apiURL = "https://api-staging-staging-62e9.up.railway.app"
    static let supabaseURL = "https://rmehfwdzxyrsdpvwgozm.supabase.co"
    static let supabaseAnonKey = StagingSecrets.supabaseAnonKey
    static let keychainService = "com.wewere.session.staging"
    #else
    static let isStaging = false
    static let urlScheme = "wewere"
    static let apiURL = "https://api-production-77f0.up.railway.app"
    static let supabaseURL = Secrets.supabaseURL
    static let supabaseAnonKey = Secrets.supabaseAnonKey
    // Preserve existing production sessions during this configuration change.
    static let keychainService = "com.wewere.session"
    #endif
}
