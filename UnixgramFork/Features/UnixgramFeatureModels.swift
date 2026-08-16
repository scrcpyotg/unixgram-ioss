import Foundation

struct UGConversation: Identifiable, Hashable {
    let id: String
    let title: String
    let username: String
    let isOnline: Bool
    let isVerified: Bool
    let avatarSymbol: String
}

struct UGChatMessage: Identifiable, Hashable {
    enum Kind: Hashable {
        case text(String)
        case photo(caption: String?)
        case voice(duration: TimeInterval)
        case gift(title: String, stars: Int)
    }

    let id: String
    let senderID: String
    let date: Date
    let isOutgoing: Bool
    let kind: Kind
    var isRead: Bool
}

struct UGStory: Identifiable, Hashable {
    let id: String
    let author: String
    let username: String
    let postedAt: Date
    let gradientIndex: Int
    let caption: String
    let viewed: Bool
}

struct UGGift: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let price: Int
    let resaleValue: Int?
    let rarity: String
}

struct UGPremiumFeature: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

enum UGMockData {
    static let conversation = UGConversation(
        id: "demo-chat",
        title: "unix",
        username: "@unixgram",
        isOnline: true,
        isVerified: true,
        avatarSymbol: "U"
    )

    static let messages: [UGChatMessage] = [
        .init(id: "m1", senderID: "unix", date: .now.addingTimeInterval(-900), isOutgoing: false, kind: .text("привет 👋"), isRead: true),
        .init(id: "m2", senderID: "me", date: .now.addingTimeInterval(-810), isOutgoing: true, kind: .text("тестирую iOS клиент Unixgram"), isRead: true),
        .init(id: "m3", senderID: "unix", date: .now.addingTimeInterval(-600), isOutgoing: false, kind: .voice(duration: 14), isRead: true),
        .init(id: "m4", senderID: "me", date: .now.addingTimeInterval(-420), isOutgoing: true, kind: .photo(caption: "первый билд на айфоне"), isRead: true),
        .init(id: "m5", senderID: "unix", date: .now.addingTimeInterval(-240), isOutgoing: false, kind: .gift(title: "Мишка", stars: 50), isRead: true),
        .init(id: "m6", senderID: "me", date: .now.addingTimeInterval(-60), isOutgoing: true, kind: .text("работает 🔥"), isRead: false)
    ]

    static let stories: [UGStory] = [
        .init(id: "s1", author: "aeternaldeV", username: "@aeternal", postedAt: .now.addingTimeInterval(-1800), gradientIndex: 0, caption: "первый Unixgram на iPhone", viewed: false),
        .init(id: "s2", author: "unix", username: "@unixgram", postedAt: .now.addingTimeInterval(-3600), gradientIndex: 1, caption: "Unixgram update", viewed: false),
        .init(id: "s3", author: "Unixgram Testing", username: "@unixtest", postedAt: .now.addingTimeInterval(-7200), gradientIndex: 2, caption: "testing stories", viewed: true)
    ]

    static let gifts: [UGGift] = [
        .init(id: "g1", title: "Мишка", emoji: "🧸", price: 50, resaleValue: 43, rarity: "Обычный"),
        .init(id: "g2", title: "Сердце", emoji: "💗", price: 75, resaleValue: 64, rarity: "Редкий"),
        .init(id: "g3", title: "Звезда", emoji: "⭐️", price: 100, resaleValue: 85, rarity: "Редкий"),
        .init(id: "g4", title: "Кристалл", emoji: "💎", price: 250, resaleValue: 215, rarity: "Эпический"),
        .init(id: "g5", title: "Корона", emoji: "👑", price: 500, resaleValue: 430, rarity: "Легендарный")
    ]

    static let premiumFeatures: [UGPremiumFeature] = [
        .init(icon: "checkmark.seal.fill", title: "До 7 особых галочек", subtitle: "Больше персонализации профиля"),
        .init(icon: "camera.viewfinder", title: "Скриншот-уведомления", subtitle: "Дополнительные настройки приватности"),
        .init(icon: "paintpalette.fill", title: "Расширенное оформление", subtitle: "Больше вариантов внешнего вида профиля"),
        .init(icon: "star.fill", title: "Premium-значок", subtitle: "Выделение профиля в Unixgram"),
        .init(icon: "sparkles", title: "Эксклюзивные возможности", subtitle: "Premium-функции по мере их появления")
    ]
}
