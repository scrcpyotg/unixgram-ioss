import Foundation

enum UGNotificationKind: String, Hashable {
    case like
    case comment
    case reply
    case mention
    case support
    case message
    case repost
    case follow
    case gift
    case other
}

struct UGNotificationPage: Hashable {
    let notifications: [UGNotificationItem]
    let nextCursor: String?

    init(raw: UGJSONValue) {
        let root = raw.objectValue

        let listValue: UGJSONValue? = {
            if let array = raw.arrayValue { return .array(array) }
            guard let root else { return nil }

            for key in ["notifications", "items", "list", "events", "activity"] {
                if let value = root[key], value.arrayValue != nil {
                    return value
                }
            }

            for key in ["page", "result", "payload"] {
                guard let nested = root[key]?.objectValue else { continue }
                for listKey in ["notifications", "items", "list", "events", "activity"] {
                    if let value = nested[listKey], value.arrayValue != nil {
                        return value
                    }
                }
            }

            return nil
        }()

        notifications = (listValue?.arrayValue ?? []).compactMap(UGNotificationItem.init(raw:))

        func cursor(in object: [String: UGJSONValue]?) -> String? {
            guard let object else { return nil }
            for key in ["nextCursor", "next_cursor", "cursor", "next"] {
                if let value = object[key]?.stringValue, !value.isEmpty {
                    return value
                }
            }
            return nil
        }

        nextCursor = cursor(in: root)
            ?? cursor(in: root?["pageInfo"]?.objectValue)
            ?? cursor(in: root?["page"]?.objectValue)
    }
}

struct UGNotificationActor: Hashable {
    let id: String?
    let username: String?
    let displayName: String?
    let avatarURL: String?

    var visibleName: String {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty { return trimmedName }
        if let username, !username.isEmpty { return "@\(username)" }
        return "Кто-то"
    }
}

struct UGNotificationPostPreview: Hashable {
    let id: String?
    let content: String?
    let imageURL: String?
}

struct UGNotificationItem: Identifiable, Hashable {
    let id: String
    let type: String
    let kind: UGNotificationKind
    let createdAt: String?
    let isRead: Bool

    let actor: UGNotificationActor?
    let title: String?
    let body: String?

    let postID: String?
    let post: UGNotificationPostPreview?
    let commentID: String?
    let conversationID: String?
    let messageID: String?
    let amountStars: Int?

    init?(raw: UGJSONValue) {
        guard let object = raw.objectValue else { return nil }

        let metadata = object["metadata"]?.objectValue
            ?? object["meta"]?.objectValue
            ?? object["data"]?.objectValue

        func firstValue(_ keys: [String]) -> UGJSONValue? {
            for key in keys {
                if let value = object[key] { return value }
                if let value = metadata?[key] { return value }
            }
            return nil
        }

        func firstString(_ keys: [String]) -> String? {
            firstValue(keys)?.stringValue
        }

        func firstInt(_ keys: [String]) -> Int? {
            firstValue(keys)?.intValue
        }

        func firstBool(_ keys: [String]) -> Bool? {
            firstValue(keys)?.boolValue
        }

        let nestedActor = ["actor", "user", "fromUser", "sourceUser", "author", "sender"]
            .compactMap { object[$0]?.objectValue }
            .first
            ?? ["actor", "user", "fromUser", "sourceUser", "author", "sender"]
                .compactMap { metadata?[$0]?.objectValue }
                .first

        let actor: UGNotificationActor? = nestedActor.map { value -> UGNotificationActor in
            UGNotificationActor(
                id: value.firstString(["id", "userId", "actorId"]),
                username: value.firstString(["username", "handle"]),
                displayName: value.firstString(["displayName", "name", "fullName"]),
                avatarURL: value.firstString(["avatarUrl", "avatarURL", "avatar", "photoUrl", "photoURL"])
            )
        } ?? { () -> UGNotificationActor? in
            let actorID = firstString(["actorId", "userId", "fromUserId", "senderId"])
            let username = firstString(["actorUsername", "username", "fromUsername", "senderUsername"])
            let displayName = firstString(["actorDisplayName", "displayName", "fromDisplayName", "senderDisplayName"])
            let avatar = firstString(["actorAvatarUrl", "avatarUrl", "fromAvatarUrl", "senderAvatarUrl"])

            if actorID == nil, username == nil, displayName == nil, avatar == nil { return nil }
            return UGNotificationActor(id: actorID, username: username, displayName: displayName, avatarURL: avatar)
        }()

        let postObject = ["post", "targetPost", "subjectPost"]
            .compactMap { object[$0]?.objectValue }
            .first
            ?? ["post", "targetPost", "subjectPost"]
                .compactMap { metadata?[$0]?.objectValue }
                .first

        let post = postObject.map { value in
            UGNotificationPostPreview(
                id: value.firstString(["id", "postId"]),
                content: value.firstString(["content", "text", "caption"]),
                imageURL: value.firstString(["imageUrl", "thumbnailUrl", "coverUrl"])
                    ?? value["imageUrls"]?.arrayValue?.compactMap(\.stringValue).first
            )
        }

        let id = firstString(["id", "notificationId", "eventId"])
            ?? "notification-\(UInt(bitPattern: raw.hashValue))"
        let type = firstString(["type", "kind", "event", "eventType", "notificationType", "action"])
            ?? "unknown"
        let title = firstString(["title", "headline"])
        let body = firstString(["body", "message", "text", "content", "description"])

        self.id = id
        self.type = type
        self.kind = Self.classify(type: type, title: title, body: body)
        self.createdAt = firstString(["createdAt", "created_at", "timestamp", "time", "date"])

        if let explicit = firstBool(["read", "isRead", "seen", "viewed"]) {
            self.isRead = explicit
        } else {
            self.isRead = firstValue(["readAt", "seenAt", "viewedAt"])?.isNull == false
        }

        self.actor = actor
        self.title = title
        self.body = body
        self.postID = firstString(["postId", "targetPostId", "subjectPostId"])
            ?? post?.id
            ?? firstString(["entityId", "targetId"]).flatMap { value in
                Self.classify(type: type, title: title, body: body) == .message ? nil : value
            }
        self.post = post
        self.commentID = firstString(["commentId", "replyId", "targetCommentId"])
        self.conversationID = firstString(["conversationId", "chatId", "dialogId"])
        self.messageID = firstString(["messageId", "targetMessageId"])
        self.amountStars = firstInt(["stars", "amountStars", "starAmount", "amount"])
    }

    var actorName: String { actor?.visibleName ?? "Кто-то" }

    var systemTitle: String {
        switch kind {
        case .like: return "Новый лайк"
        case .comment: return "Новый комментарий"
        case .reply: return "Новый ответ"
        case .mention: return "Вас отметили"
        case .support: return "Вас поддержали"
        case .message: return "Новое сообщение"
        case .repost: return "Новый репост"
        case .follow: return "Новый подписчик"
        case .gift: return "Новый подарок"
        case .other: return title ?? "Unixgram"
        }
    }

    var humanText: String {
        if let title, let body, !title.isEmpty, !body.isEmpty {
            return "\(title) · \(body)"
        }

        switch kind {
        case .like:
            if commentID != nil {
                return "\(actorName) поставил(а) лайк вашему комментарию"
            }
            return "\(actorName) поставил(а) лайк вашему посту"
        case .comment:
            return "\(actorName) прокомментировал(а) ваш пост"
        case .reply:
            return "\(actorName) ответил(а) на ваш комментарий"
        case .mention:
            if commentID != nil {
                return "\(actorName) упомянул(а) вас в комментарии"
            }
            return "\(actorName) упомянул(а) вас"
        case .support:
            if let amountStars, amountStars > 0 {
                return "\(actorName) поддержал(а) вас на \(amountStars) ⭐"
            }
            return "\(actorName) поддержал(а) вас"
        case .message:
            return "\(actorName) написал(а) вам"
        case .repost:
            return "\(actorName) сделал(а) репост вашего поста"
        case .follow:
            return "\(actorName) подписался(ась) на вас"
        case .gift:
            return "\(actorName) отправил(а) вам подарок"
        case .other:
            return body ?? title ?? "Новое событие в Unixgram"
        }
    }

    var systemBody: String {
        var text = humanText
        if let postText = post?.content?.trimmingCharacters(in: .whitespacesAndNewlines),
           !postText.isEmpty,
           !text.contains(postText) {
            let preview = String(postText.prefix(90))
            text += ": \(preview)"
        }
        return text
    }

    private static func classify(type: String, title: String?, body: String?) -> UGNotificationKind {
        let haystack = [type, title, body]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if haystack.contains("reply") || haystack.contains("ответ") { return .reply }
        if haystack.contains("mention") || haystack.contains("tag") || haystack.contains("отмет") || haystack.contains("упом") { return .mention }
        if haystack.contains("donat") || haystack.contains("support") || haystack.contains("поддерж") || haystack.contains("tip") || haystack.contains("stars") { return .support }
        if haystack.contains("message") || haystack.contains("direct") || haystack.contains("сообщ") { return .message }
        if haystack.contains("like") || haystack.contains("heart") || haystack.contains("лайк") { return .like }
        if haystack.contains("comment") || haystack.contains("коммент") { return .comment }
        if haystack.contains("repost") || haystack.contains("share") || haystack.contains("репост") { return .repost }
        if haystack.contains("follow") || haystack.contains("подпис") { return .follow }
        if haystack.contains("gift") || haystack.contains("подар") { return .gift }
        return .other
    }
}

extension UGJSONValue {
    var objectValue: [String: UGJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [UGJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value):
            if value.rounded() == value { return String(Int(value)) }
            return String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .number(let value): return value != 0
        case .string(let value):
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        default: return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .number(let value): return Int(value)
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

private extension Dictionary where Key == String, Value == UGJSONValue {
    func firstString(_ keys: [String]) -> String? {
        for key in keys {
            if let value = self[key]?.stringValue, !value.isEmpty { return value }
        }
        return nil
    }
}
