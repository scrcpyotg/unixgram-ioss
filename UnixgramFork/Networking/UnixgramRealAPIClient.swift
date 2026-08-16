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


    func feed(limit: Int = 15, cursor: String? = nil) async throws -> UGFeedResponse {
        var components = URLComponents()
        components.path = "/api/social/feed"
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = items

        let path = components.string ?? "/api/social/feed?limit=\(limit)"

        // The web client is confirmed to use this route. Decode through a tolerant wrapper.
        struct Payload: Decodable {
            let posts: [UGFeedPost]?
            let items: [UGFeedPost]?
            let nextCursor: String?
            let cursor: String?
        }

        let data: Payload = try await request(pathWithQuery: path)
        return UGFeedResponse(
            posts: data.posts ?? data.items ?? [],
            nextCursor: data.nextCursor ?? data.cursor
        )
    }

    func sendFeedSignal(
        postId: String,
        signal: String,
        value: Bool? = nil
    ) async throws {
        struct Body: Encodable {
            let postId: String
            let signal: String
            let value: Bool?
        }

        try await ensureCSRF()
        let _: UGFeedSignalResponse = try await request(
            path: "/api/social/feed/signal",
            method: "POST",
            body: Body(postId: postId, signal: signal, value: value),
            requiresCSRF: true
        )
    }


    func notificationsUnreadCount() async throws -> Int {
        let data: UGUnreadCountResponse = try await request(
            path: "/api/social/notifications/unread-count"
        )
        return data.unreadCount
    }

    /// Loads the notification/activity list from the same notifications resource that
    /// Unixgram already exposes for unread count and read-state mutations. The payload
    /// is intentionally decoded as `UGJSONValue` because the web response can contain
    /// different shapes for likes, comments, mentions, donations and gifts.
    func notifications(limit: Int = 50, cursor: String? = nil) async throws -> UGNotificationPage {
        var components = URLComponents()
        components.path = "/api/social/notifications"

        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = query

        let raw: UGJSONValue = try await request(
            pathWithQuery: components.string ?? "/api/social/notifications?limit=\(limit)"
        )
        return UGNotificationPage(raw: raw)
    }

    func messagesUnreadCount() async throws -> Int {
        // Exact HAR response:
        // { "success": true, "data": { "unreadChats": 0 } }
        let data: UGMessagesUnreadCountResponse = try await request(
            path: "/api/social/messages/unread-count"
        )
        return data.unreadChats
    }

    func markNotificationRead(notificationId: String) async throws {
        struct Body: Encodable {
            let mode: String
            let notificationId: String
        }
        try await ensureCSRF()
        let _: UGJSONValue = try await request(
            path: "/api/social/notifications",
            method: "PATCH",
            body: Body(mode: "single", notificationId: notificationId),
            requiresCSRF: true
        )
    }

    func peopleYouMayKnow() async throws -> [UGSuggestedPerson] {
        let data: UGPeopleResponse = try await request(
            path: "/api/social/people-you-may-know"
        )
        return data.people
    }

    func drafts() async throws -> [UGDraftDTO] {
        let data: UGDraftsResponse = try await request(path: "/api/social/drafts")
        return data.drafts
    }

    func verificationRequest() async throws -> UGVerificationRequest? {
        let data: UGVerificationResponse = try await request(
            path: "/api/social/verification"
        )
        return data.request
    }

    func messageFolders() async throws -> [UGMessageFolder] {
        let data: UGMessageFoldersResponse = try await request(
            path: "/api/social/messages/folders"
        )
        return data.folders
    }

    func pinnedMessages(conversationId: String) async throws -> [UGMessageDTO] {
        let data: UGPinnedMessagesResponse = try await request(
            path: "/api/social/messages/\(conversationId)/pinned"
        )
        return data.items
    }

    func scheduledMessages(conversationId: String) async throws -> [UGMessageDTO] {
        let data: UGScheduledMessagesResponse = try await request(
            path: "/api/social/messages/\(conversationId)/scheduled"
        )
        return data.messages
    }

    func realFeed(limit: Int = 15, cursor: String? = nil) async throws -> UGFeedHARResponse {
        var components = URLComponents()
        components.path = "/api/social/feed"

        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = items

        return try await request(
            pathWithQuery: components.string ?? "/api/social/feed?limit=\(limit)"
        )
    }

    // HAR showed /api/social/feed/signal is analytics, NOT like/bookmark.
    func sendFeedViewSignal(
        postId: String,
        dwellMs: Int,
        visibleRatio: Double,
        completed: Bool,
        returned: Bool = false
    ) async throws {
        try await ensureCSRF()
        let body = UGFeedEventsBody(
            events: [
                .init(
                    postId: postId,
                    dwellMs: dwellMs,
                    visibleRatio: visibleRatio,
                    completed: completed,
                    returned: returned
                )
            ]
        )
        let _: UGFeedSignalResponse = try await request(
            path: "/api/social/feed/signal",
            method: "POST",
            body: body,
            requiresCSRF: true
        )
    }

    func markPostViewed(postId: String) async throws {
        try await ensureCSRF()
        let _: UGSimpleOKResponse = try await request(
            path: "/api/social/posts/\(postId)/view",
            method: "POST",
            bodyData: Data("{}".utf8),
            requiresCSRF: true
        )
    }

    func markStoryViewed(storyId: String) async throws {
        try await ensureCSRF()
        let _: UGStoryViewResponse = try await request(
            path: "/api/social/stories/\(storyId)/view",
            method: "POST",
            bodyData: Data("{}".utf8),
            requiresCSRF: true
        )
    }

    func updateDifference(box: String, pts: Int) async throws -> UGUpdateDifferenceResponse {
        var components = URLComponents()
        components.path = "/api/updates/difference"
        components.queryItems = [
            URLQueryItem(name: "box", value: box),
            URLQueryItem(name: "pts", value: String(pts))
        ]
        return try await request(pathWithQuery: components.string ?? "/api/updates/difference")
    }


    func publicProfile(username: String) async throws -> UGPublicProfile {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let data: UGPublicProfileResponse = try await request(
            path: "/api/social/users/\(escaped)"
        )
        return data.profile
    }

    func profilePosts(
        username: String,
        cursor: String? = nil,
        limit: Int = 15
    ) async throws -> UGProfilePostsResponse {
        try await profilePagedRequest(
            username: username,
            section: "posts",
            cursor: cursor,
            limit: limit
        )
    }

    func profileReplies(
        username: String,
        cursor: String? = nil,
        limit: Int = 15
    ) async throws -> UGProfileRepliesResponse {
        try await profilePagedRequest(
            username: username,
            section: "replies",
            cursor: cursor,
            limit: limit
        )
    }

    func profileMedia(
        username: String,
        cursor: String? = nil,
        limit: Int = 18
    ) async throws -> UGProfileMediaResponse {
        try await profilePagedRequest(
            username: username,
            section: "media",
            cursor: cursor,
            limit: limit
        )
    }

    func profileStories(username: String) async throws -> [UGProfileStory] {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let data: UGProfileStoriesResponse = try await request(
            path: "/api/social/users/\(escaped)/stories"
        )
        return data.stories
    }

    func profileGifts(username: String, page: Int = 0, limit: Int = 24) async throws -> UGProfileGiftsPayload {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return try await request(
            path: "/api/social/users/\(escaped)/gifts?limit=\(limit)&page=\(page)"
        )
    }

    func profileFollowers(username: String) async throws -> [UGUserMini] {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let data: UGProfileUsersResponse = try await request(
            path: "/api/social/users/\(escaped)/followers"
        )
        return data.users
    }

    func profileFollowing(username: String) async throws -> [UGUserMini] {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let data: UGProfileUsersResponse = try await request(
            path: "/api/social/users/\(escaped)/following"
        )
        return data.users
    }

    private func profilePagedRequest<T: Decodable>(
        username: String,
        section: String,
        cursor: String?,
        limit: Int
    ) async throws -> T {
        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username

        var components = URLComponents()
        components.path = "/api/social/users/\(escaped)/\(section)"

        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = query

        return try await request(
            pathWithQuery: components.string ?? "/api/social/users/\(escaped)/\(section)"
        )
    }


    struct UploadedPostMedia: Sendable {
        let url: String
        let thumb: String?
        let posterUrl: String?
    }

    func uploadPostImage(
        data: Data,
        filename: String = "post.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> UploadedPostMedia {
        struct UploadPayload: Decodable {
            let url: String
            let thumb: String?
            let posterUrl: String?
        }

        try await ensureCSRF()

        let boundary = "UnixgramBoundary-\(UUID().uuidString)"
        var body = Data()

        func append(_ value: String) {
            body.append(Data(value.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"kind\"\r\n\r\n")
        append("post\r\n")
        append("--\(boundary)--\r\n")

        let payload: UploadPayload = try await request(
            pathWithQuery: "/api/account/upload",
            method: "POST",
            bodyData: body,
            requiresCSRF: true,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        return UploadedPostMedia(
            url: payload.url,
            thumb: payload.thumb,
            posterUrl: payload.posterUrl
        )
    }

    func createPost(
        content: String,
        uploadedImage: UploadedPostMedia? = nil
    ) async throws -> UGJSONValue {
        struct Body: Encodable {
            let content: String
            let imageUrl: String?
            let imageUrls: [String]?
            let imageThumbs: [String]?
        }

        try await ensureCSRF()

        // Text-only POST /api/social/posts is already confirmed by the app.
        // The fresh HAR confirms the media upload itself. The rich post body is not
        // present in HAR because the web client does not expose the create mutation
        // there, so image fields mirror Unixgram's own feed object (imageUrl,
        // imageUrls, imageThumbs). Keep these isolated here for easy adjustment.
        let body = Body(
            content: content,
            imageUrl: uploadedImage?.url,
            imageUrls: uploadedImage.map { [$0.url] },
            imageThumbs: uploadedImage?.thumb.map { [$0] }
        )

        return try await request(
            path: "/api/social/posts",
            method: "POST",
            body: body,
            requiresCSRF: true
        )
    }


    // MARK: - Post interactions (v0.18)

    func togglePostLike(postId: String) async throws -> UGPostLikeMutation {
        try await ensureCSRF()
        return try await request(
            path: "/api/social/posts/\(postId)/like",
            method: "POST",
            bodyData: Data(),
            requiresCSRF: true
        )
    }

    func togglePostRepost(postId: String) async throws -> UGPostRepostMutation {
        try await ensureCSRF()
        return try await request(
            path: "/api/social/posts/\(postId)/repost",
            method: "POST",
            bodyData: Data(),
            requiresCSRF: true
        )
    }

    func createPostComment(
        postId: String,
        content: String,
        parentCommentId: String? = nil
    ) async throws -> UGPostComment {
        struct Body: Encodable {
            let content: String
            let parentCommentId: String?

            enum CodingKeys: String, CodingKey {
                case content
                case parentCommentId
                case imageUrl
                case voiceUrl
                case voiceDurationMs
                case videoUrl
                case videoDurationMs
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(content, forKey: .content)

                if let parentCommentId {
                    try container.encode(parentCommentId, forKey: .parentCommentId)
                } else {
                    try container.encodeNil(forKey: .parentCommentId)
                }

                try container.encodeNil(forKey: .imageUrl)
                try container.encodeNil(forKey: .voiceUrl)
                try container.encodeNil(forKey: .voiceDurationMs)
                try container.encodeNil(forKey: .videoUrl)
                try container.encodeNil(forKey: .videoDurationMs)
            }
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw UnixgramClientError.emptyComment
        }

        try await ensureCSRF()

        let payload: UGPostCommentCreateResponse = try await request(
            path: "/api/social/posts/\(postId)/comments",
            method: "POST",
            body: Body(content: trimmed, parentCommentId: parentCommentId),
            requiresCSRF: true
        )
        return payload.comment
    }

    func postComments(
        postId: String,
        sort: String = "new",
        limit: Int = 50
    ) async throws -> UGPostCommentsPayload {
        var components = URLComponents()
        components.path = "/api/social/posts/\(postId)/comments"
        components.queryItems = [
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        return try await request(
            pathWithQuery: components.string ?? "/api/social/posts/\(postId)/comments"
        )
    }

    /// Loads replies for one top-level post comment.
    /// Unixgram already exposes `parentCommentId` on comment objects and uses the same
    /// field when a reply is created, so the first request mirrors that contract.
    /// Two read-only fallbacks are kept because different web builds have used a
    /// dedicated replies route while keeping the response model identical.
    func postCommentReplies(
        postId: String,
        commentId: String,
        limit: Int = 50
    ) async throws -> [UGPostComment] {
        var primary = URLComponents()
        primary.path = "/api/social/posts/\(postId)/comments"
        primary.queryItems = [
            URLQueryItem(name: "parentCommentId", value: commentId),
            URLQueryItem(name: "sort", value: "old"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let payload: UGPostCommentsPayload = try? await request(
            pathWithQuery: primary.string ?? "/api/social/posts/\(postId)/comments?parentCommentId=\(commentId)"
        ) {
            let filtered = payload.comments.filter { $0.parentCommentId == commentId }
            if !filtered.isEmpty || payload.comments.isEmpty {
                return filtered
            }
        }

        let fallbackPaths = [
            "/api/social/posts/\(postId)/comments/\(commentId)/replies?limit=\(limit)",
            "/api/social/comments/\(commentId)/replies?limit=\(limit)"
        ]

        var lastError: Error?
        for path in fallbackPaths {
            do {
                let payload: UGPostCommentsPayload = try await request(pathWithQuery: path)
                let replies = payload.comments.filter {
                    $0.parentCommentId == nil || $0.parentCommentId == commentId
                }
                return replies
            } catch {
                lastError = error
            }
        }

        if let lastError { throw lastError }
        return []
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
        requiresCSRF: Bool = false,
        contentType: String = "application/json"
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
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
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
    case emptyComment

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Unixgram-сессия не авторизована"
        case .rateLimited: "Слишком много запросов. Попробуйте позже."
        case .invalidResponse: "Unixgram вернул неизвестный ответ"
        case .loginSessionMissing: "Не удалось получить сессию из веб-входа"
        case .emptyComment: "Комментарий не может быть пустым"
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
