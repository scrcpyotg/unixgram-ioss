import Foundation
import Security

/// Secure persistence for Unixgram authentication cookies.
///
/// WKWebView can drop session-only cookies after the app process is terminated.
/// Keeping a copy in Keychain lets the native client restore the same authenticated
/// web session on the next launch without storing passwords or session secrets in
/// UserDefaults/files.
enum UnixgramSessionCookieVault {
    private static let service = "com.aeterna.unixgramfork.unixgram-session-cookies"
    private static let account = "unixgram.com"

    private struct StoredCookie: Codable {
        let name: String
        let value: String
        let domain: String
        let path: String
        let isSecure: Bool
        let isHTTPOnly: Bool
        let expiresDate: Date?

        init(_ cookie: HTTPCookie) {
            name = cookie.name
            value = cookie.value
            domain = cookie.domain
            path = cookie.path
            isSecure = cookie.isSecure
            isHTTPOnly = cookie.isHTTPOnly
            expiresDate = cookie.expiresDate
        }

        var isExpired: Bool {
            if let expiresDate { return expiresDate <= Date() }
            return false
        }

        func makeCookie() -> HTTPCookie? {
            guard !isExpired else { return nil }

            var parts = ["\(name)=\(value)"]
            if !domain.isEmpty { parts.append("Domain=\(domain)") }
            parts.append("Path=\(path.isEmpty ? "/" : path)")
            if isSecure { parts.append("Secure") }
            if isHTTPOnly { parts.append("HttpOnly") }
            if let expiresDate {
                parts.append("Expires=\(Self.httpDateFormatter.string(from: expiresDate))")
            }

            let scheme = isSecure ? "https" : "http"
            let normalizedHost = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard let origin = URL(string: "\(scheme)://\(normalizedHost.isEmpty ? "unixgram.com" : normalizedHost)/") else {
                return nil
            }

            let headers = ["Set-Cookie": parts.joined(separator: "; ")]
            return HTTPCookie.cookies(withResponseHeaderFields: headers, for: origin).first
        }

        private static let httpDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            return formatter
        }()
    }

    static func load() -> [HTTPCookie] {
        var query: [String: Any] = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let stored = try? JSONDecoder().decode([StoredCookie].self, from: data)
        else {
            return []
        }

        let cookies = stored.compactMap { $0.makeCookie() }
        if cookies.count != stored.count {
            save(cookies)
        }
        return cookies
    }

    static func save(_ cookies: [HTTPCookie]) {
        let unixgramCookies = cookies
            .filter { $0.domain.lowercased().contains("unixgram.com") }
            .filter { cookie in
                guard let expires = cookie.expiresDate else { return true }
                return expires > Date()
            }

        guard !unixgramCookies.isEmpty else {
            clear()
            return
        }

        let stored = unixgramCookies.map(StoredCookie.init)
        guard let data = try? JSONEncoder().encode(stored) else { return }

        SecItemDelete(baseQuery as CFDictionary)

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
