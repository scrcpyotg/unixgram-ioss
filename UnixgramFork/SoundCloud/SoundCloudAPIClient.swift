import Foundation

enum SoundCloudAPIError: LocalizedError {
    case invalidResponse
    case http(Int, String)
    case noPlayableStream

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "SoundCloud вернул некорректный ответ."
        case .http(let status, let message):
            return message.isEmpty ? "SoundCloud HTTP \(status)." : message
        case .noPlayableStream:
            return "Этот трек SoundCloud не разрешает воспроизводить во внешнем приложении или для него доступен только ограниченный поток."
        }
    }
}

private extension SoundCloudAPIError {
    var isRecoverableStreamLookupFailure: Bool {
        switch self {
        case .http(let status, _):
            return status == 400 || status == 404
        case .noPlayableStream:
            return true
        default:
            return false
        }
    }
}

final class SoundCloudAPIClient {
    static let shared = SoundCloudAPIClient()

    private let baseURL = URL(string: "https://api.soundcloud.com")!
    private let decoder = JSONDecoder()

    private init() {}

    func me(session: SoundCloudSession) async throws -> SoundCloudMe {
        try await get(path: "/me", session: session)
    }

    func searchTracks(_ query: String, session: SoundCloudSession, limit: Int = 30) async throws -> [SoundCloudTrack] {
        let params = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "access", value: "playable,preview,blocked"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "linked_partitioning", value: "true")
        ]
        let response: SoundCloudPaginatedTracks = try await get(path: "/tracks", items: params, session: session)
        return response.collection
    }

    func likedTracks(session: SoundCloudSession, limit: Int = 50) async throws -> [SoundCloudTrack] {
        let response: SoundCloudPaginatedTracks = try await get(
            path: "/me/likes/tracks",
            items: [
                URLQueryItem(name: "limit", value: String(limit)),
                // Include the full catalog metadata. Restricted tracks fall back to the official SoundCloud Widget.
                URLQueryItem(name: "access", value: "playable,preview,blocked"),
                URLQueryItem(name: "linked_partitioning", value: "true")
            ],
            session: session
        )
        return response.collection
    }

    func recentlyPlayed(session: SoundCloudSession) async throws -> [SoundCloudTrack] {
        // SoundCloud explicitly documents that this endpoint is NOT paginated.
        // `linked_partitioning` caused a 400 on the current API.
        let response: SoundCloudPaginatedTracks = try await get(
            path: "/me/recently-played/tracks",
            items: [URLQueryItem(name: "access", value: "playable,preview,blocked")],
            session: session
        )
        return response.collection
    }

    func playlists(session: SoundCloudSession, limit: Int = 50) async throws -> [SoundCloudPlaylist] {
        let response: SoundCloudPaginatedPlaylists = try await get(
            path: "/me/playlists",
            items: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "show_tracks", value: "false"),
                URLQueryItem(name: "linked_partitioning", value: "true")
            ],
            session: session
        )
        return response.collection
    }

    func streamURL(for track: SoundCloudTrack, session: SoundCloudSession) async throws -> URL {
        guard track.access?.lowercased() == "playable" else {
            throw SoundCloudAPIError.noPlayableStream
        }

        // Official SoundCloud custom-player flow:
        // authorize /tracks/{track}/stream and use its redirect target as the media URL.
        do {
            return try await redirectedStreamURL(
                identifier: track.resolvedURN,
                session: session
            )
        } catch let error as SoundCloudAPIError {
            guard error.isRecoverableStreamLookupFailure else { throw error }
        }

        // Numeric-id fallback while SoundCloud finishes the id -> URN migration.
        do {
            return try await redirectedStreamURL(
                identifier: String(track.id),
                session: session
            )
        } catch let error as SoundCloudAPIError {
            guard error.isRecoverableStreamLookupFailure else { throw error }
        }


        throw SoundCloudAPIError.noPlayableStream
    }

    private func redirectedStreamURL(
        identifier: String,
        session: SoundCloudSession,
        allowRefreshRetry: Bool = true
    ) async throws -> URL {
        let accessToken = try await session.validAccessToken()
        let url = baseURL
            .appendingPathComponent("tracks")
            .appendingPathComponent(identifier)
            .appendingPathComponent("stream")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let redirectDelegate = SoundCloudRedirectCaptureDelegate()
        let ephemeral = URLSessionConfiguration.ephemeral
        ephemeral.requestCachePolicy = .reloadIgnoringLocalCacheData
        let urlSession = URLSession(configuration: ephemeral)

        let (data, response) = try await urlSession.data(for: request, delegate: redirectDelegate)

        guard let http = response as? HTTPURLResponse else {
            throw SoundCloudAPIError.invalidResponse
        }

        if http.statusCode == 401, allowRefreshRetry {
            _ = try await session.forceRefreshAccessToken()
            return try await redirectedStreamURL(
                identifier: identifier,
                session: session,
                allowRefreshRetry: false
            )
        }

        if let redirectURL = await redirectDelegate.redirectURL {
            return redirectURL
        }

        // Some deployments may follow/resolve internally and return a media URL directly.
        if (200..<300).contains(http.statusCode),
           let finalURL = http.url,
           finalURL.host != baseURL.host {
            return finalURL
        }

        guard (200..<400).contains(http.statusCode) else {
            throw SoundCloudAPIError.http(
                http.statusCode,
                readableAPIError(status: http.statusCode, data: data)
            )
        }

        throw SoundCloudAPIError.noPlayableStream
    }

    func like(track: SoundCloudTrack, session: SoundCloudSession) async throws {
        try await empty(
            method: "POST",
            path: "/likes/tracks/\(encoded(track.resolvedURN))",
            session: session
        )
    }

    func unlike(track: SoundCloudTrack, session: SoundCloudSession) async throws {
        try await empty(
            method: "DELETE",
            path: "/likes/tracks/\(encoded(track.resolvedURN))",
            session: session
        )
    }

    func repost(track: SoundCloudTrack, session: SoundCloudSession) async throws {
        try await empty(
            method: "POST",
            path: "/reposts/tracks/\(encoded(track.resolvedURN))",
            session: session
        )
    }

    private func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func get<T: Decodable>(
        path: String,
        items: [URLQueryItem] = [],
        session: SoundCloudSession
    ) async throws -> T {
        try await request(method: "GET", path: path, items: items, session: session)
    }

    private func empty(
        method: String,
        path: String,
        session: SoundCloudSession
    ) async throws {
        let _: EmptyResponse = try await request(method: method, path: path, session: session)
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        items: [URLQueryItem] = [],
        session: SoundCloudSession,
        allowRefreshRetry: Bool = true
    ) async throws -> T {
        let accessToken = try await session.validAccessToken()
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = items.isEmpty ? nil : items

        guard let url = components.url else { throw SoundCloudAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("OAuth \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SoundCloudAPIError.invalidResponse
        }

        if http.statusCode == 401, allowRefreshRetry {
            _ = try await session.forceRefreshAccessToken()
            return try await self.request(
                method: method,
                path: path,
                items: items,
                session: session,
                allowRefreshRetry: false
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            throw SoundCloudAPIError.http(
                http.statusCode,
                readableAPIError(status: http.statusCode, data: data)
            )
        }

        if T.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw error
        }
    }

    private func readableAPIError(status: Int, data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return "SoundCloud: \(message)"
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return "SoundCloud: \(error)"
            }
        }
        return "SoundCloud HTTP \(status). Не удалось выполнить запрос."
    }

    private struct EmptyResponse: Decodable {}
}


private actor SoundCloudRedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    private(set) var redirectURL: URL?

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let target = request.url
        Task { [weak self] in
            await self?.storeRedirect(target)
        }

        // Stop before URLSession downloads the audio body.
        completionHandler(nil)
    }

    private func storeRedirect(_ url: URL?) {
        if redirectURL == nil {
            redirectURL = url
        }
    }
}
