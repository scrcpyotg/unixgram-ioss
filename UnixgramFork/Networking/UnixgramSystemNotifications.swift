import Foundation
import SwiftUI
import UserNotifications
import UIKit

extension Notification.Name {
    static let unixgramSystemNotificationTapped = Notification.Name("UnixgramSystemNotificationTapped")
    static let unixgramRemotePushRegistration = Notification.Name("UnixgramRemotePushRegistration")
}

@MainActor
final class UnixgramSystemNotificationCenter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var socialUnread: Int = 0
    @Published private(set) var messagesUnread: Int = 0
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var remoteRegistrationMessage: String?

    private let center = UNUserNotificationCenter.current()
    private var monitorTask: Task<Void, Never>?
    private var currentUserID: String?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        center.delegate = self

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .unixgramRemotePushRegistration,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.remoteRegistrationMessage = notification.userInfo?["message"] as? String
                }
            }
        )
    }

    deinit {
        monitorTask?.cancel()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var permissionLabel: String {
        switch authorizationStatus {
        case .authorized: return "Включены"
        case .provisional: return "Тихо включены"
        case .ephemeral: return "Временно включены"
        case .denied: return "Выключены в iOS"
        case .notDetermined: return "Не настроены"
        @unknown default: return "Неизвестно"
        }
    }

    func activate(currentUserID: String) async {
        self.currentUserID = currentUserID
        await refreshAuthorizationStatus()

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }

        startMonitoringIfNeeded()
    }

    func deactivate() {
        monitorTask?.cancel()
        monitorTask = nil
        currentUserID = nil
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()

            if granted {
                // This asks APNs for a token when the signing profile allows it.
                // If the current sideload profile has no aps-environment entitlement,
                // iOS reports the failure through UnixgramPushAppDelegate without
                // breaking local notification delivery.
                UIApplication.shared.registerForRemoteNotifications()
            }

            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func refreshNow(shouldNotify: Bool = false) async {
        guard let currentUserID else { return }
        await poll(currentUserID: currentUserID, shouldNotify: shouldNotify)
    }

    private func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    private func startMonitoringIfNeeded() {
        guard monitorTask == nil, let currentUserID else { return }

        monitorTask = Task { [weak self] in
            guard let self else { return }

            await self.poll(currentUserID: currentUserID, shouldNotify: false)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                await self.poll(currentUserID: currentUserID, shouldNotify: true)
            }
        }
    }

    private func poll(currentUserID: String, shouldNotify: Bool) async {
        async let socialPageTask = safe { try await UnixgramRealAPIClient.shared.notifications(limit: 60) }
        async let socialUnreadTask = safe { try await UnixgramRealAPIClient.shared.notificationsUnreadCount() }
        async let messagesUnreadTask = safe { try await UnixgramRealAPIClient.shared.messagesUnreadCount() }
        async let conversationsTask = safe { try await UnixgramRealAPIClient.shared.conversations() }

        let socialPage = await socialPageTask
        let socialUnreadValue = await socialUnreadTask
        let messagesUnreadValue = await messagesUnreadTask
        let conversations = await conversationsTask

        if let socialUnreadValue { socialUnread = socialUnreadValue }
        if let messagesUnreadValue { messagesUnread = messagesUnreadValue }

        if let socialPage {
            await processSocialNotifications(
                socialPage.notifications,
                userID: currentUserID,
                shouldNotify: shouldNotify
            )
        }

        if let conversations {
            await processConversations(
                conversations,
                userID: currentUserID,
                shouldNotify: shouldNotify
            )
        }

        lastRefreshAt = Date()
    }

    private func processSocialNotifications(
        _ notifications: [UGNotificationItem],
        userID: String,
        shouldNotify: Bool
    ) async {
        let defaults = UserDefaults.standard
        let key = "UGSeenSocialNotificationIDs.\(userID)"
        let seededKey = "UGSeenSocialNotificationSeeded.\(userID)"

        var seen = Set(defaults.stringArray(forKey: key) ?? [])
        let isSeeded = defaults.bool(forKey: seededKey)

        if !isSeeded {
            seen.formUnion(notifications.map(\.id))
            defaults.set(Array(seen.suffix(300)), forKey: key)
            defaults.set(true, forKey: seededKey)
            return
        }

        for notification in notifications.reversed() where !seen.contains(notification.id) {
            seen.insert(notification.id)

            guard shouldNotify,
                  !notification.isRead,
                  notification.kind != .message else { continue }

            await scheduleSocialNotification(notification)
        }

        if seen.count > 300 {
            let recent = notifications.map(\.id)
            var trimmed = Array(recent.prefix(220))
            for id in seen where trimmed.count < 300 && !trimmed.contains(id) {
                trimmed.append(id)
            }
            defaults.set(trimmed, forKey: key)
        } else {
            defaults.set(Array(seen), forKey: key)
        }
    }

    private func processConversations(
        _ conversations: [UGConversationDTO],
        userID: String,
        shouldNotify: Bool
    ) async {
        let defaults = UserDefaults.standard
        let key = "UGSeenConversationMessageIDs.\(userID)"
        let seededKey = "UGSeenConversationSeeded.\(userID)"
        var seenByConversation = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        let isSeeded = defaults.bool(forKey: seededKey)

        if !isSeeded {
            for conversation in conversations {
                if let id = conversation.lastMessage?.id {
                    seenByConversation[conversation.id] = id
                }
            }
            defaults.set(seenByConversation, forKey: key)
            defaults.set(true, forKey: seededKey)
            return
        }

        for conversation in conversations {
            guard let message = conversation.lastMessage else { continue }
            let oldMessageID = seenByConversation[conversation.id]
            seenByConversation[conversation.id] = message.id

            guard shouldNotify,
                  oldMessageID != nil,
                  oldMessageID != message.id,
                  (conversation.unreadCount ?? 0) > 0,
                  message.senderId != userID else { continue }

            await scheduleMessageNotification(conversation: conversation, message: message)
        }

        defaults.set(seenByConversation, forKey: key)
    }

    private func scheduleSocialNotification(_ notification: UGNotificationItem) async {
        let content = UNMutableNotificationContent()
        content.title = notification.systemTitle
        content.body = notification.systemBody
        content.sound = .default
        content.badge = NSNumber(value: socialUnread + messagesUnread)
        content.threadIdentifier = notification.postID ?? "unixgram-social"
        content.categoryIdentifier = "UNIXGRAM_SOCIAL"
        content.userInfo = [
            "kind": notification.kind.rawValue,
            "notificationId": notification.id,
            "postId": notification.postID ?? "",
            "commentId": notification.commentID ?? "",
            "conversationId": notification.conversationID ?? "",
            "actorUsername": notification.actor?.username ?? ""
        ]

        let request = UNNotificationRequest(
            identifier: "social-\(notification.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )
        try? await center.add(request)
    }

    private func scheduleMessageNotification(
        conversation: UGConversationDTO,
        message: UGLastMessage
    ) async {
        let content = UNMutableNotificationContent()
        content.title = conversation.title
            ?? conversation.members?.first?.displayName
            ?? conversation.members?.first?.username
            ?? "Новое сообщение"
        content.body = message.content?.isEmpty == false ? message.content! : "Новое сообщение в Unixgram"
        content.sound = .default
        content.badge = NSNumber(value: socialUnread + messagesUnread)
        content.threadIdentifier = conversation.id
        content.categoryIdentifier = "UNIXGRAM_MESSAGE"
        content.userInfo = [
            "kind": UGNotificationKind.message.rawValue,
            "conversationId": conversation.id,
            "messageId": message.id
        ]

        let request = UNNotificationRequest(
            identifier: "message-\(message.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )
        try? await center.add(request)
    }

    private func safe<T>(_ operation: @escaping () async throws -> T) async -> T? {
        do { return try await operation() }
        catch { return nil }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            NotificationCenter.default.post(
                name: .unixgramSystemNotificationTapped,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

final class UnixgramPushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "UGAPNSDeviceToken")
        UserDefaults.standard.removeObject(forKey: "UGAPNSRegistrationError")

        NotificationCenter.default.post(
            name: .unixgramRemotePushRegistration,
            object: nil,
            userInfo: ["message": "APNs-токен получен. Нужна привязка токена к серверу Unixgram."]
        )
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        let message = error.localizedDescription
        UserDefaults.standard.set(message, forKey: "UGAPNSRegistrationError")

        NotificationCenter.default.post(
            name: .unixgramRemotePushRegistration,
            object: nil,
            userInfo: ["message": "APNs недоступен для текущей подписи: \(message)"]
        )
    }
}
