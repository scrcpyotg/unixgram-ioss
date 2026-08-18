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
            URLQueryItem(name: "access", value: "playable"),
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
                // /me/likes/tracks defaults to playable, preview AND blocked.
                // Do not offer tracks that SoundCloud explicitly blocks off-platform.
                URLQueryItem(name: "access", value: "playable,preview"),
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
            items: [URLQueryItem(name: "access", value: "playable,preview")],
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
        if track.access?.lowercased() == "blocked" {
            throw SoundCloudAPIError.noPlayableStream
        }

        // Primary path from the current SoundCloud OpenAPI: track URN.
        do {
            if let url = try await officialStreamURL(identifier: track.resolvedURN, session: session) {
                return url
            }
        } catch let error as SoundCloudAPIError {
            guard error.isRecoverableStreamLookupFailure else { throw error }
        }

        // SoundCloud is in the middle of the id -> URN migration. Some stream backends
        // still accept/expect the numeric id even when metadata already exposes a URN.
        do {
            if let url = try await officialStreamURL(identifier: String(track.id), session: session) {
                return url
            }
        } catch let error as SoundCloudAPIError {
            guard error.isRecoverableStreamLookupFailure else { throw error }
        }

        // Last-resort fallback for public tracks. This does not expose user cookies or
        // OAuth tokens and uses the existing logged-out SoundCloud transport.
        if track.access?.lowercased() != "blocked" {
            if let url = try? await SoundCloudPublicClient.shared.streamURL(for: track) {
                return url
            }
        }

        throw SoundCloudAPIError.noPlayableStream
    }

    private func officialStreamURL(identifier: String, session: SoundCloudSession) async throws -> URL? {
        let streams: SoundCloudStreams = try await get(
            path: "/tracks/\(encoded(identifier))/streams",
            session: session
        )
        return streams.preferredURL
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
