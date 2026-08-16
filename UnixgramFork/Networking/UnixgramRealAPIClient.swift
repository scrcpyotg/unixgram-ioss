import Foundation
import WebKit

actor UnixgramRealAPIClient {
    static let shared = UnixgramRealAPIClient()

    let baseURL = URL(string: "https://unixgram.com")!
    let protoWebSocketURL = URL(string: "wss://proto.unixgram.com/unixproto")!

    private let session: URLSession
    private var csrfToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = .shared
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // Copies the authenticated Unixgram web session from WKWebView to URLSession.
    @MainActor
    func importWebKitCookies() async {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.contains("unixgram.com") {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    func bootstrapCSRF() async throws {
        let response: UGCSRFResponse = try await request(
            path: "/api/auth/csrf",
            method: "GET",
            requiresCSRF: false
        )
        csrfToken = response.csrfToken
    }

    func me() async throws -> UGCurrentAccount {
        let data: UGCurrentAccountResponse = try await request(path: "/api/auth/me")
        return data.account
    }

    func accounts() async throws -> UGAccountsResponse {
        try await request(path: "/api/auth/accounts")
    }

    func conversations() async throws -> [UGConversationDTO] {
        let data: UGConversationsResponse = try await request(path: "/api/social/messages")
        return data.conversations
    }

    func conversation(id: String) async throws -> UGConversationDetailResponse {
        try await request(path: "/api/social/messages/\(id)")
    }

    func sendMessage(
        conversationId: String,
        content: String,
        replyToId: String? = nil,
        replyQuote: String? = nil,
        effectId: String? = nil
    ) async throws -> UGSendMessageResponse {
        struct Body: Encodable {
            let content: String
            let replyToId: String?
            let replyQuote: String?
            let effectId: String?
            let clientMessageId: String
        }

        try await ensureCSRF()

        return try await request(
            path: "/api/social/messages/\(conversationId)",
            method: "POST",
            body: Body(
                content: content,
                replyToId: replyToId,
                replyQuote: replyQuote,
                effectId: effectId,
                clientMessageId: UUID().uuidString.lowercased()
            ),
            requiresCSRF: true
        )
    }

    func setTyping(conversationId: String, typing: Bool) async throws {
        struct Body: Encodable {
            let typing: Bool
            let typingAction: String
        }
        try await ensureCSRF()
        let _: UGSimpleOKResponse = try await request(
            path: "/api/social/messages/\(conversationId)",
            method: "PATCH",
            body: Body(typing: typing, typingAction: "typing"),
            requiresCSRF: true
        )
    }

    func markRead(conversationId: String) async throws {
        try await ensureCSRF()
        let _: UGSimpleOKResponse = try await request(
            path: "/api/social/messages/\(conversationId)/read",
            method: "POST",
            bodyData: Data("{}".utf8),
            requiresCSRF: true
        )
    }

    func communities() async throws -> [UGCommunityDTO] {
        let data: UGCommunitiesResponse = try await request(path: "/api/social/communities")
        return data.communities
    }

    func adminedCommunities() async throws -> [UGAdminedCommunityDTO] {
        let data: UGAdminedCommunitiesResponse = try await request(path: "/api/social/communities/admined")
        return data.channels
    }

    func presence(ids: [String]) async throws -> [String: UGPresenceDTO] {
        var components = URLComponents()
        components.path = "/api/social/presence"
        components.queryItems = [URLQueryItem(name: "ids", value: ids.joined(separator: ","))]
        let data: UGPresenceResponse = try await request(pathWithQuery: components.string ?? "/api/social/presence")
        return data.presence
    }

    func unixProtoToken() async throws -> UGUnixProtoTokenResponse {
        try await request(path: "/api/unixproto/token")
    }


    func notificationPreferences() async throws -> UGNotificationPreferences {
        let data: UGNotificationPreferencesResponse = try await request(
            path: "/api/social/notifications/preferences"
        )
        return data.preferences
    }

    func accountSessions() async throws -> [UGAccountSession] {
        let data: UGSessionsResponse = try await request(path: "/api/account/sessions")
        return data.sessions
    }

    func integrations() async throws -> [UGIntegration] {
        let data: UGIntegrationsResponse = try await request(path: "/api/integrations")
        return data.integrations
    }

    private func ensureCSRF() async throws {
        if csrfToken == nil {
            try await bootstrapCSRF()
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        requiresCSRF: Bool = false
    ) async throws -> T {
        try await request(pathWithQuery: path, method: method, bodyData: nil, requiresCSRF: requiresCSRF)
    }

    private func request<T: Decodable, B: Encodable>(
        path: String,
        method: String,
        body: B,
        requiresCSRF: Bool
    ) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        return try await request(pathWithQuery: path, method: method, bodyData: bodyData, requiresCSRF: requiresCSRF)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        bodyData: Data?,
        requiresCSRF: Bool
    ) async throws -> T {
        try await request(pathWithQuery: path, method: method, bodyData: bodyData, requiresCSRF: requiresCSRF)
    }

    private func request<T: Decodable>(
        pathWithQuery: String,
        method: String = "GET",
        bodyData: Data? = nil,
        requiresCSRF: Bool = false
    ) async throws -> T {
        guard let url = URL(string: pathWithQuery, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("https://unixgram.com", forHTTPHeaderField: "Origin")
        req.setValue("https://unixgram.com/dashboard", forHTTPHeaderField: "Referer")

        if let bodyData {
            req.httpBody = bodyData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresCSRF, let csrfToken {
            req.setValue(csrfToken, forHTTPHeaderField: "x-csrf-token")
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw UnixgramClientError.notAuthenticated
        }

        if http.statusCode == 429 {
            throw UnixgramClientError.rateLimited
        }

        let envelope = try JSONDecoder().decode(UGAPIEnvelope<T>.self, from: data)

        if envelope.success, let value = envelope.data {
            return value
        }

        if let apiError = envelope.error {
            throw apiError
        }

        throw UnixgramClientError.invalidResponse
    }
}

enum UnixgramClientError: LocalizedError {
    case notAuthenticated
    case rateLimited
    case invalidResponse
    case loginSessionMissing

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Unixgram-сессия не авторизована"
        case .rateLimited: "Слишком много запросов. Попробуйте позже."
        case .invalidResponse: "Unixgram вернул неизвестный ответ"
        case .loginSessionMissing: "Не удалось получить сессию из веб-входа"
        }
    }
}

private extension WKHTTPCookieStore {
    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { continuation.resume(returning: $0) }
        }
    }
}
