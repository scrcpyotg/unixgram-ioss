import Foundation

struct UGAPIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: UGAPIError?
}

struct UGAPIError: Decodable, Error, LocalizedError {
    let code: String
    let message: String
    let details: [String]?

    var errorDescription: String? { message }
}

struct UGCurrentAccountResponse: Decodable {
    let account: UGCurrentAccount
}

struct UGCurrentAccount: Decodable, Identifiable {
    let id: String
    let email: String?
    let username: String
    let role: String?
    let isActive: Bool?
    let emailVerifiedAt: String?
    let twoFactorEnabled: Bool?
    let twoFactorMethod: String?
    let createdAt: String?
    let registrationNumber: Int?
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let coverUrl: String?
    let location: String?
    let website: String?
    let birthDate: String?
    let usernameAliases: [String]?
    let verificationBadge: String?
    let premium: Bool?
    let onboardingCompletedAt: String?
    let language: String?

    // Unixgram web builds have used different names for the same real Stars balance.
    // Decoding optional aliases keeps older/newer API payloads compatible without
    // inventing a balance when the server does not expose one.
    let starsBalance: Int?
    let starBalance: Int?
    let stars: Int?
    let balanceStars: Int?

    var resolvedStarsBalance: Int? {
        starsBalance ?? starBalance ?? stars ?? balanceStars
    }
}

struct UGAccountsResponse: Decodable {
    let accounts: [UGAccountSummary]
    let limit: Int?
}

struct UGAccountSummary: Decodable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let isActive: Bool?
    let unread: Int?
}

struct UGConversationsResponse: Decodable {
    let conversations: [UGConversationDTO]
}

struct UGConversationDTO: Decodable, Identifiable {
    let id: String
    let type: String?
    let source: String?
    let createdAt: String?
    let isSelf: Bool?
    let title: String?
    let avatarUrl: String?
    let memberCount: Int?
    let pinned: Bool?
    let archived: Bool?
    let markedUnread: Bool?
    let folderId: String?
    let unreadCount: Int?
    let members: [UGUserMini]?
    let lastMessage: UGLastMessage?
}

struct UGUserMini: Decodable, Identifiable {
    let id: String
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let premium: Bool?
    let emojiStatus: String?
    let profilePalette: String?
    let verificationBadge: String?
}

struct UGLastMessage: Decodable, Identifiable {
    let id: String
    let content: String?
    let createdAt: String?
    let senderId: String?
    let isRead: Bool?
    let media: UGJSONValue?
}

struct UGConversationDetailResponse: Decodable {
    let conversationId: String
    let type: String?
    let source: String?
    let isSelf: Bool?
    let muted: Bool?
    let autoDeleteSeconds: Int?
    let peer: UGPeer?
    let group: UGJSONValue?
    let messages: [UGMessageDTO]
}

struct UGPeer: Decodable, Identifiable {
    let id: String
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let showOnlineStatus: Bool?
    let isFromTelegram: Bool?
    let isService: Bool?
    let premium: Bool?
    let emojiStatus: String?
    let profilePalette: String?
    let verificationBadge: String?
}

struct UGMessageDTO: Decodable, Identifiable {
    let id: String
    let clientMessageId: String?
    let content: String?
    let kind: String?
    let forwardedFromName: String?
    let createdAt: String?
    let editedAt: String?
    let pinned: Bool?
    let media: UGJSONValue?
    let giveaway: UGJSONValue?
    let poll: UGJSONValue?
    let effectId: String?
    let scheduledAt: String?
    let scheduleRepeat: String?
    let factCheck: UGJSONValue?
    let captionAbove: Bool?
    let replyTo: UGJSONValue?
    let sender: UGUserMini?
    let reactions: [UGReactionDTO]?
}

struct UGReactionDTO: Decodable {
    let emoji: String
    let count: Int
    let reactedByViewer: Bool?
    let users: [UGReactionUser]?
}

struct UGReactionUser: Decodable, Identifiable {
    let id: String
    let displayName: String?
    let avatarUrl: String?
}

struct UGSendMessageResponse: Decodable {
    let ok: Bool
    let messageId: String?
    let message: UGMessageDTO?
}

struct UGSimpleOKResponse: Decodable {
    let ok: Bool
}

struct UGCSRFResponse: Decodable {
    let csrfToken: String
}

struct UGUnixProtoTokenResponse: Decodable {
    let ok: Bool?
    let token: String
    let expiresAt: String?
}

struct UGCommunitiesResponse: Decodable {
    let communities: [UGCommunityDTO]
}

struct UGCommunityDTO: Decodable, Identifiable {
    let id: String
    let type: String?
    let handle: String
    let handleAliases: [String]?
    let name: String
    let description: String?
    let avatarUrl: String?
    let bannerUrl: String?
    let location: String?
    let website: String?
    let category: String?
    let verified: Bool?
    let membersCount: Int?
    let postsCount: Int?
    let createdAt: String?
    let viewerRole: String?
    let isMember: Bool?
    let canPost: Bool?
    let isOwner: Bool?
}

struct UGAdminedCommunitiesResponse: Decodable {
    let channels: [UGAdminedCommunityDTO]
}

struct UGAdminedCommunityDTO: Decodable, Identifiable {
    let id: String
    let handle: String
    let name: String
    let avatarUrl: String?
    let verified: Bool?
    let subscribersCount: Int?
}

struct UGPresenceResponse: Decodable {
    let presence: [String: UGPresenceDTO]
}

struct UGPresenceDTO: Decodable {
    let online: Bool
    let lastSeenAt: String?
}

// Tolerant value for fields whose exact API schema varies by message/media type.
enum UGJSONValue: Decodable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: UGJSONValue])
    case array([UGJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([String: UGJSONValue].self) { self = .object(v) }
        else if let v = try? container.decode([UGJSONValue].self) { self = .array(v) }
        else { self = .null }
    }
}


struct UGNotificationPreferencesResponse: Decodable {
    let preferences: UGNotificationPreferences
}

struct UGNotificationPreferences: Decodable {
    let likes: Bool
    let comments: Bool
    let reposts: Bool
    let mentions: Bool
    let follows: Bool
    let gifts: Bool
    let donations: Bool
    let profileViews: Bool
    let newPosts: Bool
    let newStories: Bool
    let storyReplies: Bool
    let enabled: Bool
    let sound: Bool
}

struct UGSessionsResponse: Decodable {
    let sessions: [UGAccountSession]
}

struct UGAccountSession: Decodable, Identifiable {
    let id: String
    let source: String?
    let userAgent: String?
    let ipAddress: String?
    let expiresAt: String?
    let createdAt: String?
    let current: Bool
    let deviceName: String?
    let platform: String?
    let appVersion: String?
    let lastSeenAt: String?
}

struct UGIntegrationsResponse: Decodable {
    let integrations: [UGIntegration]
}

struct UGIntegration: Decodable, Identifiable {
    var id: String { provider }
    let provider: String
    let available: Bool
    let connected: Bool
    let accountName: String?
    let accountAvatarUrl: String?
    let connectedAt: String?
}


struct UGFeedResponse: Decodable {
    let posts: [UGFeedPost]
    let nextCursor: String?
}

struct UGFeedPost: Decodable, Identifiable {
    let id: String
    let kind: String?
    let content: String?
    let createdAt: String?
    let editedAt: String?
    let author: UGUserMini?
    let community: UGCommunityMini?
    let media: [UGFeedMedia]?
    let poll: UGFeedPoll?
    let stats: UGFeedStats?
    let viewer: UGFeedViewerState?
    let gift: UGJSONValue?
    let repostOf: UGJSONValue?
    let quotedPost: UGJSONValue?
    let tags: [String]?
}

struct UGCommunityMini: Decodable, Identifiable {
    let id: String
    let handle: String?
    let name: String?
    let avatarUrl: String?
    let verified: Bool?
}

struct UGFeedMedia: Decodable, Identifiable {
    let id: String?
    let type: String?
    let url: String?
    let previewUrl: String?
    let width: Int?
    let height: Int?
    let duration: Double?
    let mimeType: String?

    var stableID: String {
        id ?? url ?? previewUrl ?? UUID().uuidString
    }
}

struct UGFeedPoll: Decodable {
    let id: String?
    let question: String?
    let multiple: Bool?
    let options: [UGFeedPollOption]?
}

struct UGFeedPollOption: Decodable, Identifiable {
    let id: String
    let text: String
    let votes: Int?
    let selectedByViewer: Bool?
}

struct UGFeedStats: Decodable {
    let likes: Int?
    let comments: Int?
    let reposts: Int?
    let views: Int?
    let bookmarks: Int?
}

struct UGFeedViewerState: Decodable {
    let liked: Bool?
    let reposted: Bool?
    let bookmarked: Bool?
}

struct UGFeedSignalResponse: Decodable {
    let ok: Bool
}

struct UGCommunityDetailResponse: Decodable {
    let community: UGCommunityDTO
    let recentPosts: [UGFeedPost]?
}


struct UGUnreadCountResponse: Decodable {
    let unreadCount: Int
}

struct UGPeopleResponse: Decodable {
    let people: [UGSuggestedPerson]
}

struct UGSuggestedPerson: Decodable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let avatarUrl: String?
    let verificationBadge: String?
    let premium: Bool?
    let reason: UGSuggestionReason?
    let mutualsCount: Int?
    let mutualAvatars: [UGMutualAvatar]?
}

struct UGSuggestionReason: Decodable {
    let kind: String?
    let label: String?
}

struct UGMutualAvatar: Decodable, Identifiable {
    let id: String
    let displayName: String?
    let avatarUrl: String?
}

struct UGDraftsResponse: Decodable {
    let drafts: [UGDraftDTO]
}

struct UGDraftDTO: Decodable, Identifiable {
    let id: String
    let type: String?
    let content: String?
    let updatedAt: String?
    let communityId: String?
}

struct UGVerificationResponse: Decodable {
    let request: UGVerificationRequest?
}

struct UGVerificationRequest: Decodable, Identifiable {
    let id: String
    let status: String?
    let createdAt: String?
    let updatedAt: String?
    let reason: String?
}

struct UGMessageFoldersResponse: Decodable {
    let folders: [UGMessageFolder]
}

struct UGMessageFolder: Decodable, Identifiable {
    let id: String
    let name: String?
    let icon: String?
    let position: Int?
}

struct UGPinnedMessagesResponse: Decodable {
    let items: [UGMessageDTO]
}

struct UGScheduledMessagesResponse: Decodable {
    let messages: [UGMessageDTO]
}

struct UGFeedHARResponse: Decodable {
    let feed: [UGHARFeedPost]
    let pageInfo: UGFeedPageInfo
    let suggestions: [UGSuggestedPerson]?
    let trends: [UGFeedTrend]?

    var nextCursor: String? { pageInfo.nextCursor }
}

struct UGHARFeedPost: Decodable, Identifiable {
    let id: String
    let content: String?
    let imageUrl: String?
    let imageUrls: [String]?
    let imageThumbs: [String]?
    let videoUrl: String?
    let attachments: [UGJSONValue]?
    let music: UGHARMusic?
    let createdAt: String?
    let editedAt: String?
    let replyToId: String?
    let likedByViewer: Bool?
    let repostedByViewer: Bool?
    let bookmarkedByViewer: Bool?
    let likesCount: Int?
    let commentsCount: Int?
    let repostsCount: Int?
    let bookmarksCount: Int?
    let viewsCount: Int?
    let uniqueViewsCount: Int?
    let viewedByViewer: Bool?
    let pinned: Bool?
    let notificationsMuted: Bool?
    let boostedUntil: String?
    let poll: UGHARPoll?
    let audience: String?
    let locked: Bool?
    let isNsfw: Bool?
    let lockedPriceStars: Int?
    let viewerReaction: String?
    let reactionsCount: Int?
    let author: UGHARFeedAuthor?
    let community: UGCommunityDTO?
}

struct UGHARFeedAuthor: Decodable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let verificationBadge: String?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let registrationNumber: Int?
    let isFollowing: Bool?
    let isViewer: Bool?
    let premium: Bool?
    let emojiStatus: String?
    let profilePalette: String?
    let badges: [UGJSONValue]?
}

struct UGHARMusic: Decodable {
    let title: String?
    let artist: String?
    let coverUrl: String?
    let provider: String?
    let durationMs: Int?
    let externalId: String?
    let previewUrl: String?
    let externalUrl: String?
}

struct UGHARPoll: Decodable {
    let id: String?
    let question: String?
    let options: [UGHARPollOption]?
    let multiple: Bool?
}

struct UGHARPollOption: Decodable, Identifiable {
    let id: String
    let text: String
    let votes: Int?
    let selectedByViewer: Bool?
}

struct UGFeedEventsBody: Encodable {
    struct Event: Encodable {
        let postId: String
        let dwellMs: Int
        let visibleRatio: Double
        let completed: Bool
        let returned: Bool
    }
    let events: [Event]
}

struct UGStoryViewResponse: Decodable {
    let ok: Bool?
}

struct UGUpdateDifferenceResponse: Decodable {
    let type: String?
    let boxKey: String?
    let pts: Int?
}


struct UGPublicProfileResponse: Decodable {
    let profile: UGPublicProfile
}

struct UGPublicProfile: Decodable, Identifiable {
    let id: String
    let username: String
    let displayName: String?
    let bio: String?
    let avatarUrl: String?
    let coverUrl: String?
    let location: String?
    let website: String?
    let birthDate: String?
    let usernameAliases: [String]?
    let verificationBadge: String?
    let registrationNumber: Int?
    let createdAt: String?
    let isOnline: Bool?
    let lastSeenAt: String?
    let followersCount: Int?
    let followingCount: Int?
    let postsCount: Int?
    let storiesCount: Int?
    let isViewer: Bool?
    let isFollowing: Bool?
    let followRequestSent: Bool?
    let premium: Bool?
    let profilePalette: String?
    let profileMusic: UGProfileMusic?
    let profileVibe: String?
    let badges: [UGJSONValue]?
    let giftShowcase: [UGProfileGift]?
}

struct UGProfileMusic: Decodable, Encodable, Hashable {
    let title: String?
    let artist: String?
    let coverUrl: String?
    let provider: String?
    let durationMs: Int?
    let externalId: String?
    let previewUrl: String?
    let externalUrl: String?
}

struct UGProfilePageInfo: Decodable {
    let cursor: String?
    let hasMore: Bool?
}

struct UGProfilePostsResponse: Decodable {
    let posts: [UGHARFeedPost]
    let pageInfo: UGProfilePageInfo?
}

struct UGProfileRepliesResponse: Decodable {
    let replies: [UGHARFeedPost]
    let pageInfo: UGProfilePageInfo?
}

struct UGProfileMediaResponse: Decodable {
    let posts: [UGHARFeedPost]
    let pageInfo: UGProfilePageInfo?
}

struct UGProfileStoriesResponse: Decodable {
    let stories: [UGProfileStory]
}

struct UGProfileStory: Decodable, Identifiable {
    let id: String
    let imageUrl: String?
    let videoUrl: String?
    let previewUrl: String?
    let thumbnailUrl: String?
    let text: String?
    let createdAt: String?
    let expiresAt: String?
    let viewsCount: Int?
    let likesCount: Int?
    let viewedByViewer: Bool?
    let likedByViewer: Bool?
    let music: UGProfileMusic?
    let layers: [UGJSONValue]?
}

struct UGProfileGift: Decodable, Identifiable {
    let id: String
    let title: String?
    let collectionName: String?
    let serial: Int?
    let price: Double?
    let templateSlug: String?
    let templateImageUrl: String?
    let modelPngUrl: String?
    let modelLottieUrl: String?
    let isPinned: Bool?
    let isStatusGift: Bool?
}

enum UGProfileGiftsPayload: Decodable {
    case list([UGProfileGift])
    case object(gifts: [UGProfileGift], hasMore: Bool?)

    var gifts: [UGProfileGift] {
        switch self {
        case .list(let gifts): gifts
        case .object(let gifts, _): gifts
        }
    }

    var hasMore: Bool? {
        switch self {
        case .list: false
        case .object(_, let hasMore): hasMore
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let direct = try? container.decode([UGProfileGift].self) {
            self = .list(direct)
            return
        }

        struct ObjectPayload: Decodable {
            let gifts: [UGProfileGift]
            let hasMore: Bool?
        }

        let object = try container.decode(ObjectPayload.self)
        self = .object(gifts: object.gifts, hasMore: object.hasMore)
    }
}

struct UGProfileUsersResponse: Decodable {
    let users: [UGUserMini]

    private enum CodingKeys: String, CodingKey {
        case users
        case followers
        case following
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode([UGUserMini].self, forKey: .users) {
            users = value
            return
        }
        if let value = try? container.decode([UGUserMini].self, forKey: .followers) {
            users = value
            return
        }
        if let value = try? container.decode([UGUserMini].self, forKey: .following) {
            users = value
            return
        }
        if let value = try? container.decode([UGUserMini].self, forKey: .data) {
            users = value
            return
        }

        users = []
    }
}


struct UGMessagesUnreadCountResponse: Decodable {
    let unreadChats: Int
}

struct UGFeedPageInfo: Decodable {
    let hasMore: Bool
    let nextCursor: String?
    let limit: Int?
}

struct UGFeedTrend: Decodable, Identifiable {
    var id: String { title }
    let title: String
    let meta: String?
}



// MARK: - Post interactions (v0.18)

struct UGPostLikeMutation: Decodable {
    let liked: Bool
    let likesCount: Int
}

struct UGPostRepostMutation: Decodable {
    let reposted: Bool
}

struct UGPostCommentCreateResponse: Decodable {
    let comment: UGPostComment
}

struct UGPostComment: Decodable, Identifiable {
    let id: String
    let postId: String
    let content: String?
    let imageUrl: String?
    let voiceUrl: String?
    let voiceDurationMs: Int?
    let videoUrl: String?
    let videoDurationMs: Int?
    let createdAt: String?
    let parentCommentId: String?
    let replyToId: String?
    let repliesCount: Int?
    let likesCount: Int?
    let likedByViewer: Bool?
    let author: UGHARFeedAuthor
}

struct UGPostCommentsPayload: Decodable {
    let comments: [UGPostComment]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case comments, items, replies, nextCursor, cursor, pageInfo
    }

    private struct PageInfo: Decodable {
        let nextCursor: String?
        let cursor: String?
    }

    init(from decoder: Decoder) throws {
        if let direct = try? decoder.singleValueContainer().decode([UGPostComment].self) {
            comments = direct
            nextCursor = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode([UGPostComment].self, forKey: .comments) {
            comments = value
        } else if let value = try? container.decode([UGPostComment].self, forKey: .items) {
            comments = value
        } else if let value = try? container.decode([UGPostComment].self, forKey: .replies) {
            comments = value
        } else {
            comments = []
        }

        if let value = try? container.decode(String.self, forKey: .nextCursor) {
            nextCursor = value
        } else if let value = try? container.decode(String.self, forKey: .cursor) {
            nextCursor = value
        } else if let pageInfo = try? container.decode(PageInfo.self, forKey: .pageInfo) {
            nextCursor = pageInfo.nextCursor ?? pageInfo.cursor
        } else {
            nextCursor = nil
        }
    }
}
