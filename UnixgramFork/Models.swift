import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var username: String
    var avatarURL: URL?
    var bio: String?

    static let mock = UserProfile(
        id: "me",
        displayName: "Aeterna",
        username: "aeterna",
        avatarURL: nil,
        bio: "Unixgram iOS fork"
    )
}

struct Chat: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var updatedAt: Date
}

struct Message: Identifiable, Codable, Hashable {
    let id: String
    let chatID: String
    let senderID: String
    var text: String
    let createdAt: Date
    var isOutgoing: Bool
    var status: MessageStatus
}

enum MessageStatus: String, Codable {
    case sending, sent, delivered, read, failed
}

extension Chat {
    static let mocks: [Chat] = [
        .init(id: "1", title: "Unixgram News", subtitle: "Новая версия уже близко", unreadCount: 2, isPinned: true, isMuted: false, updatedAt: .now),
        .init(id: "2", title: "Alex", subtitle: "Окей, договорились", unreadCount: 0, isPinned: true, isMuted: false, updatedAt: .now.addingTimeInterval(-800)),
        .init(id: "3", title: "Design", subtitle: "Скинул макеты", unreadCount: 7, isPinned: false, isMuted: true, updatedAt: .now.addingTimeInterval(-3400)),
        .init(id: "4", title: "Study Job", subtitle: "Посмотри обновление", unreadCount: 0, isPinned: false, isMuted: false, updatedAt: .now.addingTimeInterval(-8000))
    ]
}

extension Message {
    static func mocks(chatID: String) -> [Message] {
        [
            .init(id: "m1", chatID: chatID, senderID: "other", text: "Привет 👋", createdAt: .now.addingTimeInterval(-300), isOutgoing: false, status: .read),
            .init(id: "m2", chatID: chatID, senderID: "me", text: "Привет! Тестирую iOS-клиент.", createdAt: .now.addingTimeInterval(-180), isOutgoing: true, status: .read),
            .init(id: "m3", chatID: chatID, senderID: "other", text: "Выглядит очень неплохо.", createdAt: .now.addingTimeInterval(-60), isOutgoing: false, status: .read)
        ]
    }
}
