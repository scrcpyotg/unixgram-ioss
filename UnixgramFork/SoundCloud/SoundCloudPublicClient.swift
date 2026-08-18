import Foundation

/// Public, logged-out SoundCloud transport.
///
/// This deliberately contains no user cookies or shared account credentials.
/// It discovers the public web client ID exposed by SoundCloud's own page
/// hydration and refreshes it when SoundCloud rejects the previous one.
///
/// This is best-effort because api-v2 is a web-facing API, not the stable
/// authenticated developer API. Authenticated users use SoundCloudAPIClient.
actor SoundCloudPublicClient {
    static let shared = SoundCloudPublicClient()

    private let apiV2 = URL(string: "https://api-v2.soundcloud.com")!
    private let homepage = URL(string: "https://soundcloud.com")!
    private var clientID: String?
    private var clientIDFetchedAt: Date?

    private let decoder = JSONDecoder()

    func searchTracks(_ query: String, limit: Int = 30) async throws -> [SoundCloudTrack] {
        let id = try await validClientID()

        var components = URLComponents(
            url: apiV2.appendingPathComponent("/search/tracks"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "client_id", value: id),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: "0"),
            URLQueryItem(name: "linked_partitioning", value: "1"),
            URLQueryItem(name: "app_locale", value: "en")
        ]

        do {
            let response: SoundCloudSearchResponse = try await fetch(components.url!)
            return response.collection.filter { $0.access?.lowercased() != "blocked" }
        } catch {
            invalidateClientID()
            let fresh = try await validClientID(force: true)
            components.queryItems = components.queryItems?.map {
                $0.name == "client_id" ? URLQueryItem(name: "client_id", value: fresh) : $0
            }
            let response: SoundCloudSearchResponse = try await fetch(components.url!)
            return response.collection.filter { $0.access?.lowercased() != "blocked" }
        }
    }

    func streamURL(for input: SoundCloudTrack) async throws -> URL {
        do {
            return try await streamURLAttempt(for: input)
        } catch {
            invalidateClientID()
            _ = try await validClientID(force: true)
            return try await streamURLAttempt(for: input)
        }
    }

    private func streamURLAttempt(for input: SoundCloudTrack) async throws -> URL {
        let id = try await validClientID()
        var components = URLComponents(
            url: apiV2.appendingPathComponent("/tracks/\(input.id)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "client_id", value: id)]

        let track: SoundCloudTrack = try await fetch(components.url!)
        guard let transcoding = pickTranscoding(track.media?.transcodings ?? []) else {
            throw SoundCloudAPIError.noPlayableStream
        }

        guard var transcode = URLComponents(string: transcoding.url) else {
            throw SoundCloudAPIError.noPlayableStream
        }

        var items = transcode.queryItems ?? []
        items.append(URLQueryItem(name: "client_id", value: id))
        if let authorization = track.trackAuthorization, !authorization.isEmpty {
            items.append(URLQueryItem(name: "track_authorization", value: authorization))
        }
        transcode.queryItems = items

        let resolved: ResolvedTranscoding = try await fetch(transcode.url!)
        guard let url = URL(string: resolved.url) else {
            throw SoundCloudAPIError.noPlayableStream
        }
        return url
    }

    private func pickTranscoding(_ all: [SoundCloudTranscoding]) -> SoundCloudTranscoding? {
        let usable = all.filter { item in
            guard item.snipped != true else { return false }
            guard !item.url.localizedCaseInsensitiveContains("preview") else { return false }
            let proto = item.format?.protocolName?.lowercased() ?? ""
            return !proto.contains("encrypted")
        }

        let preferredPresets = ["aac_160k", "mp3_1_0", "opus_0_0", "abr_sq"]
        for preset in preferredPresets {
            if let item = usable.first(where: { $0.preset == preset }) {
                return item
            }
        }

        return usable.first
    }

    private func validClientID(force: Bool = false) async throws -> String {
        if !force,
           let clientID,
           let fetched = clientIDFetchedAt,
           Date().timeIntervalSince(fetched) < 6 * 60 * 60 {
            return clientID
        }

        let id = try await discoverClientID()
        clientID = id
        clientIDFetchedAt = .now
        return id
    }

    private func invalidateClientID() {
        clientID = nil
        clientIDFetchedAt = nil
    }

    private func discoverClientID() async throws -> String {
        var request = URLRequest(url: homepage)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw SoundCloudAPIError.invalidResponse
        }

        if let id = hydrationClientID(in: html) {
            return id
        }

        throw SoundCloudAPIError.http(0, "Не удалось получить публичный SoundCloud client_id.")
    }

    private func hydrationClientID(in html: String) -> String? {
        let marker = "window.__sc_hydration ="
        guard let markerRange = html.range(of: marker) else { return nil }

        let suffix = html[markerRange.upperBound...]
        guard let start = suffix.firstIndex(of: "[") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var end: String.Index?

        var index = start
        while index < html.endIndex {
            let ch = html[index]

            if inString {
                if ch == "\"" && !escaped { inString = false }
                escaped = (ch == "\\") && !escaped
                if ch != "\\" { escaped = false }
            } else {
                if ch == "\"" {
                    inString = true
                } else if ch == "[" {
                    depth += 1
                } else if ch == "]" {
                    depth -= 1
                    if depth == 0 {
                        end = html.index(after: index)
                        break
                    }
                }
            }

            index = html.index(after: index)
        }

        guard let end else { return nil }
        let json = String(html[start..<end])
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        for entry in array.reversed() {
            guard entry["hydratable"] as? String == "apiClient",
                  let payload = entry["data"] as? [String: Any],
                  let id = payload["id"] as? String,
                  !id.isEmpty else {
                continue
            }
            return id
        }

        return nil
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SoundCloudAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SoundCloudAPIError.http(
                http.statusCode,
                String(data: data, encoding: .utf8) ?? ""
            )
        }
        return try decoder.decode(T.self, from: data)
    }

    private struct ResolvedTranscoding: Decodable {
        let url: String
    }
}
