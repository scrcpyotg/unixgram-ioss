import Foundation

enum SoundCloudConfig {
    static let clientID = "jG9yuXJwXZh9XweetqXH6S71dCTEGpR2"
    static let redirectURI = "unixgramfork://soundcloud/callback"
    static let callbackScheme = "unixgramfork"

    /// Set this once the server-side token broker is deployed.
    /// Example:
    /// https://YOUR_PROJECT.supabase.co/functions/v1/soundcloud-oauth
    ///
    /// A UserDefaults override is intentionally supported so a test build can
    /// point at a freshly deployed broker without recompiling the whole app.
    static var brokerBaseURL: URL? {
        if let raw = UserDefaults.standard.string(forKey: "unixgram.soundcloud.brokerURL"),
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme?.lowercased() == "https" {
            return url
        }
        return nil
    }

    static func setBrokerBaseURL(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            UserDefaults.standard.removeObject(forKey: "unixgram.soundcloud.brokerURL")
        } else {
            UserDefaults.standard.set(value, forKey: "unixgram.soundcloud.brokerURL")
        }
    }
}
