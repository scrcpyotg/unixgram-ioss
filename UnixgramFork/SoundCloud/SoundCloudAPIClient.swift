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
            return "Для этого трека SoundCloud не вернул доступный поток."
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
                URLQueryItem(name: "linked_partitioning", value: "true")
            ],
            session: session
        )
        return response.collection
    }

    func recentlyPlayed(session: SoundCloudSession) async throws -> [SoundCloudTrack] {
        let response: SoundCloudPaginatedTracks = try await get(
            path: "/me/recently-played/tracks",
            items: [URLQueryItem(name: "linked_partitioning", value: "true")],
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
        let streams: SoundCloudStreams = try await get(
            path: "/tracks/\(track.resolvedURN.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? track.resolvedURN)/streams",
            session: session
        )
        guard let url = streams.preferredURL else { throw SoundCloudAPIError.noPlayableStream }
        return url
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
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SoundCloudAPIError.http(http.statusCode, body)
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

    private struct EmptyResponse: Decodable {}
}
