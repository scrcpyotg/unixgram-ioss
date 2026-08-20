import SwiftUI
import UIKit
import WebKit

struct UnixgramAllRealNotificationsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @EnvironmentObject private var systemNotifications: UnixgramSystemNotificationCenter

    @State private var notifications: [UGNotificationItem] = []
    @State private var prefs: UGNotificationPreferences?
    @State private var isLoading = false
    @State private var readOverrides: Set<String> = []
    @State private var errorMessage: String?
    @State private var showPreferences = false
    @State private var navigationRoute: UnixgramNotificationDeepLink?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header
                pushCard

                if isLoading && notifications.isEmpty {
                    ProgressView("Загружаем уведомления…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if notifications.isEmpty {
                    emptyState
                } else {
                    notificationSections
                }

                preferencesCard
            }
            .padding(18)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            consumePendingDeepLink()
        }
        .onChange(of: session.pendingNotificationDeepLink) { _ in
            consumePendingDeepLink()
        }
        .navigationDestination(isPresented: Binding(
            get: { navigationRoute != nil },
            set: { if !$0 { navigationRoute = nil } }
        )) {
            notificationDestination
        }
        .refreshable { await load() }
        .alert(
            "Unixgram",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Уведомления")
                    .font(.system(size: 32, weight: .bold))

                Text("Лайки, ответы, отметки и поддержка")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let unread = max(store.notificationUnread, systemNotifications.socialUnread)
            if unread > 0 {
                Text("\(unread)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(.purple)
                    .clipShape(Capsule())
            }
        }
    }

    private var pushCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.14))
                Image(systemName: systemNotifications.authorizationStatus == .denied ? "bell.slash.fill" : "bell.badge.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.purple)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("Системные уведомления")
                    .font(.system(size: 16, weight: .semibold))
                Text(systemNotifications.permissionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if systemNotifications.authorizationStatus == .denied {
                Button("Настройки") { openSystemSettings() }
                    .buttonStyle(.bordered)
                    .tint(.purple)
            } else if systemNotifications.authorizationStatus == .notDetermined {
                Button("Включить") {
                    Task { _ = await systemNotifications.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var notificationSections: some View {
        ForEach(Array(groupedNotifications.enumerated()), id: \.offset) { _, section in
            VStack(alignment: .leading, spacing: 10) {
                Text(section.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)

                VStack(spacing: 8) {
                    ForEach(section.items) { notification in
                        notificationRow(notification)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func notificationRow(_ notification: UGNotificationItem) -> some View {
        Button {
            Task { await open(notification) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                avatar(for: notification)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(notification.humanText)
                            .font(.system(size: 15, weight: isUnread(notification) ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        if let createdAt = notification.createdAt {
                            Text(relative(createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let preview = postPreviewText(for: notification), !preview.isEmpty {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(iconColor(for: notification.kind).opacity(0.8))
                                .frame(width: 3)

                            Text(preview)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)

                            if postPreviewImage(for: notification) != nil {
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 9)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 6) {
                        Image(systemName: icon(for: notification.kind))
                            .foregroundStyle(iconColor(for: notification.kind))
                        Text(kindLabel(notification.kind))
                            .foregroundStyle(.secondary)

                        if notification.kind == .support,
                           let stars = notification.amountStars,
                           stars > 0 {
                            Text("· \(stars) ⭐")
                                .foregroundStyle(.yellow)
                        }

                        Spacer()

                        if isUnread(notification) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding(13)
            .background(isUnread(notification) ? Color.purple.opacity(0.07) : Color.white.opacity(0.03))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isUnread(notification) ? Color.purple.opacity(0.18) : Color.white.opacity(0.045), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatar(for notification: UGNotificationItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let raw = notification.actor?.avatarURL,
               let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarFallback(notification.actorName)
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                avatarFallback(notification.actorName)
            }

            Image(systemName: icon(for: notification.kind))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(iconColor(for: notification.kind))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
        }
        .frame(width: 50, height: 50)
    }

    private func avatarFallback(_ name: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(width: 48, height: 48)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Image(systemName: "bell")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("Пока тихо")
                .font(.headline)
            Text(errorMessage == nil
                 ? "Новые лайки, ответы, отметки и поддержка появятся здесь."
                 : "Список пока не удалось загрузить. Потяните вниз, чтобы повторить.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPreferences.toggle()
                }
            } label: {
                HStack {
                    Text("Что присылать")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Image(systemName: showPreferences ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showPreferences {
                if let prefs {
                    preference("Лайки", prefs.likes)
                    preference("Комментарии и ответы", prefs.comments)
                    preference("Репосты", prefs.reposts)
                    preference("Отметки", prefs.mentions)
                    preference("Подписки", prefs.follows)
                    preference("Подарки", prefs.gifts)
                    preference("Поддержка / донаты", prefs.donations)
                } else {
                    Text("Настройки Unixgram пока не загрузились.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func preference(_ title: String, _ value: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(value ? Color.green : Color.secondary)
        }
        .padding(.vertical, 3)
    }

    private var groupedNotifications: [(title: String, items: [UGNotificationItem])] {
        let calendar = Calendar.current
        let now = Date()
        var today: [UGNotificationItem] = []
        var yesterday: [UGNotificationItem] = []
        var earlier: [UGNotificationItem] = []

        for notification in notifications {
            guard let date = parseDate(notification.createdAt) else {
                earlier.append(notification)
                continue
            }

            if calendar.isDateInToday(date) {
                today.append(notification)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(notification)
            } else if date > calendar.date(byAdding: .day, value: -7, to: now) ?? .distantPast {
                earlier.append(notification)
            } else {
                earlier.append(notification)
            }
        }

        var result: [(String, [UGNotificationItem])] = []
        if !today.isEmpty { result.append(("Сегодня", today)) }
        if !yesterday.isEmpty { result.append(("Вчера", yesterday)) }
        if !earlier.isEmpty { result.append(("Ранее", earlier)) }
        return result
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let pageTask = try? UnixgramRealAPIClient.shared.notifications(limit: 60)
        async let prefsTask = try? UnixgramRealAPIClient.shared.notificationPreferences()
        async let unreadTask = try? UnixgramRealAPIClient.shared.notificationsUnreadCount()

        let page = await pageTask
        let loadedPrefs = await prefsTask
        let unread = await unreadTask

        if let page {
            notifications = page.notifications.sorted { lhs, rhs in
                (parseDate(lhs.createdAt) ?? .distantPast) > (parseDate(rhs.createdAt) ?? .distantPast)
            }
            errorMessage = nil
        } else {
            errorMessage = "Не удалось получить список уведомлений Unixgram."
        }

        if let loadedPrefs { prefs = loadedPrefs }
        if let unread { store.notificationUnread = unread }

        await systemNotifications.refreshNow(shouldNotify: false)
    }

    private func open(_ notification: UGNotificationItem) async {
        if isUnread(notification) {
            readOverrides.insert(notification.id)
            do {
                try await UnixgramRealAPIClient.shared.markNotificationRead(notificationId: notification.id)
                store.notificationUnread = max(0, store.notificationUnread - 1)
            } catch {
                // Keep the screen usable even if the server's read mutation is temporarily unavailable.
            }
        }

        if notification.kind == .message || notification.conversationID != nil {
            session.selectedTab = .messages
            return
        }

        if let route = deepLink(for: notification) {
            navigationRoute = route
        }
    }

    @ViewBuilder
    private var notificationDestination: some View {
        switch navigationRoute {
        case .post(let postID, let commentID):
            UnixgramNotificationPostDestination(postID: postID, commentID: commentID)
        case .profile(let username):
            UnixgramPublicProfileView(username: username)
        case nil:
            EmptyView()
        }
    }

    private func deepLink(for notification: UGNotificationItem) -> UnixgramNotificationDeepLink? {
        switch notification.kind {
        case .follow, .support:
            if let username = notification.actor?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return .profile(username: username)
            }
            return nil

        case .like, .comment, .reply, .mention, .repost:
            if let postID = notification.postID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !postID.isEmpty {
                return .post(postID: postID, commentID: notification.commentID)
            }
            if let username = notification.actor?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return .profile(username: username)
            }
            return nil

        case .gift, .other:
            if let username = notification.actor?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return .profile(username: username)
            }
            return nil

        case .message:
            return nil
        }
    }

    private func consumePendingDeepLink() {
        guard let pending = session.pendingNotificationDeepLink else { return }
        navigationRoute = pending
        session.pendingNotificationDeepLink = nil
    }

    private func isUnread(_ notification: UGNotificationItem) -> Bool {
        !notification.isRead && !readOverrides.contains(notification.id)
    }

    private func postPreviewText(for notification: UGNotificationItem) -> String? {
        if let content = notification.post?.content?.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            return content
        }

        guard let postID = notification.postID,
              let post = store.feed.first(where: { $0.id == postID }) else {
            return notification.postID.map { "Пост · \(String($0.prefix(10)))…" }
        }

        if let content = post.content?.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            return content
        }

        return "Пост в Unixgram"
    }

    private func postPreviewImage(for notification: UGNotificationItem) -> String? {
        if let image = notification.post?.imageURL { return image }
        guard let postID = notification.postID,
              let post = store.feed.first(where: { $0.id == postID }) else { return nil }
        return post.imageUrl ?? post.imageUrls?.first
    }

    private func icon(for kind: UGNotificationKind) -> String {
        switch kind {
        case .like: return "heart.fill"
        case .comment: return "bubble.left.fill"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .mention: return "at"
        case .support: return "star.fill"
        case .message: return "envelope.fill"
        case .repost: return "arrow.2.squarepath"
        case .follow: return "person.badge.plus"
        case .gift: return "gift.fill"
        case .other: return "bell.fill"
        }
    }

    private func iconColor(for kind: UGNotificationKind) -> Color {
        switch kind {
        case .like: return .pink
        case .comment: return .cyan
        case .reply: return .blue
        case .mention: return .purple
        case .support: return .yellow
        case .message: return .indigo
        case .repost: return .green
        case .follow: return .mint
        case .gift: return .orange
        case .other: return .gray
        }
    }

    private func kindLabel(_ kind: UGNotificationKind) -> String {
        switch kind {
        case .like: return "Лайк"
        case .comment: return "Комментарий"
        case .reply: return "Ответ"
        case .mention: return "Отметка"
        case .support: return "Поддержка"
        case .message: return "Сообщение"
        case .repost: return "Репост"
        case .follow: return "Подписка"
        case .gift: return "Подарок"
        case .other: return "Событие"
        }
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = formatter.date(from: raw) { return value }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private func relative(_ raw: String) -> String {
        guard let date = parseDate(raw) else { return "" }
        return date.formatted(.relative(presentation: .numeric))
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}


private struct UnixgramNotificationPostDestination: View {
    let postID: String
    let commentID: String?

    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @State private var post: UGHARFeedPost?
    @State private var finishedLookup = false

    var body: some View {
        Group {
            if let post {
                ScrollView {
                    HARFeedPostCard(
                        post: post,
                        openCommentsInitially: commentID != nil
                    )
                    .padding(16)
                    .padding(.bottom, 90)
                }
                .background(Color.black)
            } else if finishedLookup {
                UnixgramOfficialPostWebView(postID: postID)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Открываем пост…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .navigationTitle("Пост")
        .navigationBarTitleDisplayMode(.inline)
        .task { await locatePost() }
    }

    @MainActor
    private func locatePost() async {
        if let existing = store.feed.first(where: { $0.id == postID }) {
            post = existing
            return
        }

        await store.refreshFeed()
        if let existing = store.feed.first(where: { $0.id == postID }) {
            post = existing
            return
        }

        var attempts = 0
        while post == nil, store.feedHasMore, attempts < 3 {
            attempts += 1
            await store.appendNextFeedPage()
            post = store.feed.first(where: { $0.id == postID })
        }

        finishedLookup = true
    }
}

private struct UnixgramOfficialPostWebView: UIViewRepresentable {
    let postID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        load(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func load(_ webView: WKWebView) {
        guard var components = URLComponents(string: "https://unixgram.com") else { return }
        components.path = "/post/\(postID)"
        guard let url = components.url else { return }
        webView.load(URLRequest(url: url))
    }
}
