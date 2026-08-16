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
    let language: String?
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
