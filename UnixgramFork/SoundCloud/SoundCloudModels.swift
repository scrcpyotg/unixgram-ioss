import Foundation

struct SoundCloudOAuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let scope: String?
    let tokenType: String?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
        case expiresAt
    }

    init(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int,
        scope: String?,
        tokenType: String?,
        expiresAt: Date = .now
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.scope = scope
        self.tokenType = tokenType
        self.expiresAt = expiresAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try c.decode(String.self, forKey: .accessToken)
        refreshToken = try c.decode(String.self, forKey: .refreshToken)
        expiresIn = try c.decodeIfPresent(Int.self, forKey: .expiresIn) ?? 3600
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
        tokenType = try c.decodeIfPresent(String.self, forKey: .tokenType)

        if let decoded = try c.decodeIfPresent(Date.self, forKey: .expiresAt) {
            expiresAt = decoded
        } else {
            expiresAt = Date().addingTimeInterval(TimeInterval(max(60, expiresIn)))
        }
    }

    func withFreshExpiry() -> SoundCloudOAuthToken {
        SoundCloudOAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            scope: scope,
            tokenType: tokenType,
            expiresAt: Date().addingTimeInterval(TimeInterval(max(60, expiresIn)))
        )
    }
}

struct SoundCloudMe: Codable, Identifiable {
    let id: Int
    let urn: String?
    let username: String
    let permalink: String?
    let permalinkURL: String?
    let avatarURL: String?
    let fullName: String?
    let city: String?
    let countryCode: String?
    let followersCount: Int?
    let followingsCount: Int?
    let trackCount: Int?
    let playlistCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, urn, username, permalink
        case permalinkURL = "permalink_url"
        case avatarURL = "avatar_url"
        case fullName = "full_name"
        case city
        case countryCode = "country_code"
        case followersCount = "followers_count"
        case followingsCount = "followings_count"
        case trackCount = "track_count"
        case playlistCount = "playlist_count"
    }
}

struct SoundCloudUser: Codable, Identifiable {
    let id: Int
    let urn: String?
    let username: String
    let permalinkURL: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, urn, username
        case permalinkURL = "permalink_url"
        case avatarURL = "avatar_url"
    }
}

struct SoundCloudTrack: Codable, Identifiable, Hashable {
    let id: Int
    let urn: String?
    let title: String
    let duration: Int?
    let artworkURL: String?
    let permalinkURL: String?
    let playbackCount: Int?
    let likesCount: Int?
    let repostsCount: Int?
    let commentCount: Int?
    let access: String?
    let user: SoundCloudTrackUser?
    let media: SoundCloudMedia?
    let trackAuthorization: String?

    enum CodingKeys: String, CodingKey {
        case id, urn, title, duration, access, user, media
        case artworkURL = "artwork_url"
        case permalinkURL = "permalink_url"
        case playbackCount = "playback_count"
        case likesCount = "likes_count"
        case repostsCount = "reposts_count"
        case commentCount = "comment_count"
        case trackAuthorization = "track_authorization"
    }

    static func == (lhs: SoundCloudTrack, rhs: SoundCloudTrack) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var resolvedURN: String {
        if let urn, !urn.isEmpty { return urn }
        return "soundcloud:tracks:\(id)"
    }
}

struct SoundCloudTrackUser: Codable, Hashable {
    let id: Int?
    let urn: String?
    let username: String?
    let avatarURL: String?
    let permalinkURL: String?

    enum CodingKeys: String, CodingKey {
        case id, urn, username
        case avatarURL = "avatar_url"
        case permalinkURL = "permalink_url"
    }
}

struct SoundCloudMedia: Codable, Hashable {
    let transcodings: [SoundCloudTranscoding]?
}

struct SoundCloudTranscoding: Codable, Hashable {
    let url: String
    let preset: String?
    let duration: Int?
    let snipped: Bool?
    let format: SoundCloudTranscodingFormat?
    let quality: String?
}

struct SoundCloudTranscodingFormat: Codable, Hashable {
    let protocolName: String?
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case mimeType = "mime_type"
    }
}

struct SoundCloudStreams: Codable {
    let httpMp3128URL: String?
    let hlsMp3128URL: String?
    let hlsAac160URL: String?
    let hlsAac96URL: String?
    let hlsOpus64URL: String?
    let previewMp3128URL: String?

    enum CodingKeys: String, CodingKey {
        case httpMp3128URL = "http_mp3_128_url"
        case hlsMp3128URL = "hls_mp3_128_url"
        case hlsAac160URL = "hls_aac_160_url"
        case hlsAac96URL = "hls_aac_96_url"
        case hlsOpus64URL = "hls_opus_64_url"
        case previewMp3128URL = "preview_mp3_128_url"
    }

    var preferredURL: URL? {
        [
            hlsAac160URL,
            hlsAac96URL,
            httpMp3128URL,
            hlsMp3128URL,
            hlsOpus64URL,
            previewMp3128URL
        ]
        .compactMap { $0.flatMap(URL.init(string:)) }
        .first
    }
}

struct SoundCloudPaginatedTracks: Codable {
    let collection: [SoundCloudTrack]
    let nextHref: String?

    enum CodingKeys: String, CodingKey {
        case collection
        case nextHref = "next_href"
    }

    init(from decoder: Decoder) throws {
        // Most list endpoints return { collection, next_href } when pagination is enabled.
        // /me/recently-played/tracks is explicitly non-paginated and may return an array.
        if let array = try? decoder.singleValueContainer().decode([SoundCloudTrack].self) {
            collection = array
            nextHref = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        collection = try container.decode([SoundCloudTrack].self, forKey: .collection)
        nextHref = try container.decodeIfPresent(String.self, forKey: .nextHref)
    }
}

struct SoundCloudSearchResponse: Codable {
    let collection: [SoundCloudTrack]
}

struct SoundCloudPlaylist: Codable, Identifiable {
    let id: Int
    let urn: String?
    let title: String
    let artworkURL: String?
    let permalinkURL: String?
    let trackCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, urn, title
        case artworkURL = "artwork_url"
        case permalinkURL = "permalink_url"
        case trackCount = "track_count"
    }
}

struct SoundCloudPaginatedPlaylists: Codable {
    let collection: [SoundCloudPlaylist]
    let nextHref: String?

    enum CodingKeys: String, CodingKey {
        case collection
        case nextHref = "next_href"
    }
}
