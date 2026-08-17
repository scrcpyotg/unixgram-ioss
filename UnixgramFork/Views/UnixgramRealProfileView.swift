import SwiftUI
import AVKit

struct UnixgramRealProfileView: View {
    let requestedUsername: String?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @EnvironmentObject private var dashboard: UnixgramLiveDashboardStore

    @StateObject private var content = UnixgramProfileContentStore()
    @State private var selectedTab: UnixgramProfileTab = .posts
    @State private var showSettings = false
    @State private var showCreatePost = false
    @State private var selectedStory: UGProfileStory?
    @State private var selectedGift: UGProfileGift?
    @State private var showGiftMarket = false

    init(username: String? = nil) {
        let normalized = username?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        requestedUsername = normalized?.isEmpty == false ? normalized : nil
    }

    private var targetUsername: String {
        requestedUsername ?? liveSession.currentUser?.username ?? content.profile?.username ?? ""
    }

    private var username: String {
        content.profile?.username ?? targetUsername
    }

    private var isOwnProfile: Bool {
        if content.profile?.isViewer == true { return true }
        guard let current = liveSession.currentUser?.username, !targetUsername.isEmpty else {
            return requestedUsername == nil
        }
        return current.caseInsensitiveCompare(targetUsername) == .orderedSame
    }

    private var fallbackAccount: UGCurrentAccount? {
        isOwnProfile ? liveSession.currentUser : nil
    }

    private var premiumAccent: Color? {
        UnixgramPremiumPalette.accent(
            premium: content.profile?.premium,
            palette: content.profile?.profilePalette
        )
    }

    var body: some View {
        Group {
            if content.profile != nil || fallbackAccount != nil {
                profileBody(fallbackAccount)
            } else {
                ProgressView("Загружаем профиль…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: targetUsername.lowercased()) {
            if liveSession.currentUser == nil {
                await liveSession.refreshAuthentication()
            }

            let resolved = requestedUsername ?? liveSession.currentUser?.username ?? ""
            guard !resolved.isEmpty else { return }
            await content.refresh(username: resolved, selectedTab: selectedTab)
        }
        .onChange(of: selectedTab) {
            guard !username.isEmpty else { return }
            Task {
                await content.load(tab: selectedTab, username: username)
            }
        }
        .sheet(isPresented: $showSettings) {
            if isOwnProfile, let user = liveSession.currentUser {
                UnixgramRealProfileSettingsSheet(
                    isPresented: $showSettings,
                    user: user
                )
                .environmentObject(liveSession)
                .presentationDetents([.fraction(0.82), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
                .presentationBackground(.clear)
            }
        }
        .sheet(isPresented: $showCreatePost) {
            if isOwnProfile {
                UnixgramCreatePostView {
                    selectedTab = .posts
                    Task {
                        guard !username.isEmpty else { return }
                        await content.refresh(username: username, selectedTab: .posts)
                    }
                }
                .environmentObject(liveSession)
                .environmentObject(dashboard)
            }
        }
        .fullScreenCover(item: $selectedStory) { story in
            ProfileStoryViewer(story: story)
        }
        .sheet(item: $selectedGift) { gift in
            ProfileGiftDetailSheet(gift: gift)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $showGiftMarket) {
            UnixgramGiftMarketView(username: username)
        }
    }

    private func profileBody(_ account: UGCurrentAccount?) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                profileHeader(account)
                profileTabs
                    .background(Color.black)
                tabContent
            }
        }
        .background(Color.black)
        .refreshable {
            liveSession.showRefreshingNotice()
            guard !username.isEmpty else {
                liveSession.hideNotice()
                return
            }
            await content.refresh(username: username, selectedTab: selectedTab)
            if content.errorMessage != nil {
                liveSession.showOfflineNotice()
            } else {
                liveSession.hideNotice(after: 0.5)
            }
        }
        .alert("Ошибка Unixgram", isPresented: Binding(
            get: { content.errorMessage != nil },
            set: { if !$0 { content.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(content.errorMessage ?? "")
        }
    }

    // MARK: Header

    private func profileHeader(_ account: UGCurrentAccount?) -> some View {
        let profile = content.profile
        let displayName = profile?.displayName ?? account?.displayName ?? account?.username ?? targetUsername
        let handle = profile?.username ?? account?.username ?? targetUsername
        let accent = premiumAccent

        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                cover(url: profile?.coverUrl ?? account?.coverUrl)
                    .frame(height: 285)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.55), .clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack {
                    circleActionButton("chevron.left") { dismiss() }
                    Spacer()

                    VStack(alignment: .center, spacing: 2) {
                        Text(displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(accent ?? Color.white)
                            .lineLimit(1)
                        Text("\(profile?.postsCount ?? content.posts.count) постов")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    circleActionButton("qrcode") {}
                }
                .padding(.horizontal, 18)
                .padding(.top, 15)
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    avatar(
                        url: profile?.avatarUrl ?? account?.avatarUrl,
                        name: displayName
                    )
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.black, lineWidth: 4))
                    .overlay(
                        Circle()
                            .stroke(accent?.opacity(0.78) ?? Color.clear, lineWidth: accent == nil ? 0 : 2)
                    )
                    .offset(y: -59)

                    Spacer(minLength: 8)

                    profileActions(profile)
                }
                .padding(.bottom, -59)

                HStack(spacing: 7) {
                    Text(displayName)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(accent ?? Color.white)

                    if let badge = profile?.verificationBadge ?? account?.verificationBadge,
                       badge != "NONE" {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                    }

                    if profile?.premium == true || account?.premium == true {
                        Image(systemName: "sparkles")
                            .foregroundStyle(accent ?? Color.purple)
                    }

                    if let number = profile?.registrationNumber ?? account?.registrationNumber {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.dotted")
                            Text("\(number)")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }

                Text("@\(handle)")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)

                if profile?.showOnlineStatus != false {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(profile?.isOnline == true ? Color.green : Color.secondary)
                            .frame(width: 9, height: 9)

                        Text(profile?.isOnline == true ? "В сети" : lastSeen(profile?.lastSeenAt))
                            .foregroundStyle(profile?.isOnline == true ? Color.green : Color.secondary)
                    }
                    .font(.system(size: 16))
                }

                if let aliases = profile?.usernameAliases ?? account?.usernameAliases,
                   !aliases.isEmpty {
                    (
                        Text("а также ")
                            .foregroundStyle(.secondary)
                        +
                        Text(aliases.map { "@\($0)" }.joined(separator: ", "))
                            .foregroundStyle(accent ?? Color.blue)
                    )
                    .font(.system(size: 16))
                }

                if let bio = profile?.bio ?? account?.bio,
                   !bio.isEmpty {
                    UnixgramMentionText(text: bio, font: .system(size: 17), color: .white)
                }

                if let profile, !profile.resolvedBadgeIDs.isEmpty {
                    UnixgramProfileBadgesView(ids: profile.resolvedBadgeIDs, size: 29)
                        .padding(.top, 1)
                }

                if let links = profile?.links, !links.isEmpty {
                    profileLinks(links)
                }

                HStack(spacing: 14) {
                    if let location = profile?.location ?? account?.location,
                       !location.isEmpty {
                        metadata("location", location)
                    }

                    if let website = profile?.website ?? account?.website,
                       !website.isEmpty {
                        if let url = normalizedWebsiteURL(website) {
                            Link(destination: url) {
                                metadata("link", cleanedWebsite(website))
                            }
                        } else {
                            metadata("link", cleanedWebsite(website))
                        }
                    }
                }

                if let created = profile?.joinedAt ?? profile?.createdAt ?? account?.createdAt {
                    metadata("calendar", "На Unixgram с \(friendlyDate(created))")
                }

                if let streak = profile?.streak?.current, streak > 0 {
                    HStack(spacing: 7) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak) \(dayWord(streak)) подряд")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 15, weight: .medium))
                }

                HStack(spacing: 22) {
                    NavigationLink {
                        UnixgramConnectionsView(username: username, kind: .following)
                    } label: {
                        stat(profile?.followingCount, "Подписки")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        UnixgramConnectionsView(username: username, kind: .followers)
                    } label: {
                        stat(profile?.followersCount, "Подписчики")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)

                if let music = profile?.profileMusic {
                    ProfileMusicStrip(music: music)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 0)
        }
    }

    @ViewBuilder
    private func profileActions(_ profile: UGPublicProfile?) -> some View {
        if isOwnProfile {
            Button("Редактировать") {
                showSettings = true
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(premiumAccent ?? Color.white)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(Color.black)
            .overlay(
                Capsule().stroke(
                    premiumAccent?.opacity(0.55) ?? Color.white.opacity(0.14),
                    lineWidth: 1
                )
            )
            .clipShape(Capsule())

            Button {
                showCreatePost = true
            } label: {
                profileActionIcon("square.and.pencil")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Создать пост")

            Button {
                showGiftMarket = true
            } label: {
                profileActionIcon("gift.fill", purple: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Маркет подарков")

            NavigationLink {
                UnixPlaceMarketView()
            } label: {
                profileActionIcon("bag.fill", purple: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Маркет юзов")
        } else {
            Button {
                showGiftMarket = true
            } label: {
                profileActionIcon("gift.fill", purple: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Отправить подарок")

            if profile?.isFollowing == true {
                Text("Читаю")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, 17)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14)))
                    .clipShape(Capsule())
            } else if profile?.followRequestSent == true {
                Text("Заявка отправлена")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 13)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }

    private func profileActionIcon(_ icon: String, purple: Bool = false) -> some View {
        let accent = premiumAccent ?? Color(red: 0.80, green: 0.56, blue: 1.0)

        return Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(purple ? accent : Color.white)
            .frame(width: 42, height: 42)
            .background(
                Circle()
                    .fill(purple ? accent.opacity(0.14) : Color.black.opacity(0.58))
            )
            .overlay(
                Circle()
                    .stroke(purple ? accent.opacity(0.50) : Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func profileLinks(_ links: [UGProfileLink]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                    if let raw = link.url, let url = URL(string: raw) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: linkIcon(link.platform))
                                Text(link.label?.isEmpty == false ? link.label! : cleanedWebsite(raw))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(premiumAccent ?? Color.white)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background((premiumAccent ?? Color.white).opacity(premiumAccent == nil ? 0.06 : 0.10))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var profileTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(UnixgramProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 11) {
                            HStack(spacing: 5) {
                                Text(tab.title)

                                if tab == .stories,
                                   let count = content.profile?.storiesCount,
                                   count > 0 {
                                    Text("\(count)")
                                        .font(.caption2.bold())
                                }
                            }
                            .font(.system(size: 15, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? (premiumAccent ?? Color.white)
                                    : Color.secondary
                            )

                            Capsule()
                                .fill(selectedTab == tab ? (premiumAccent ?? Color.blue) : Color.clear)
                                .frame(height: 3)
                                .padding(.horizontal, 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 58)

            Divider()
                .overlay(Color.white.opacity(0.08))
        }
    }

    // MARK: Content

    @ViewBuilder
    private var tabContent: some View {
        if content.profile?.canViewContent == false, !isOwnProfile {
            emptyState(
                icon: "lock.fill",
                title: "Закрытый профиль",
                subtitle: content.profile?.followRequestSent == true
                    ? "Заявка на подписку уже отправлена."
                    : "Контент доступен подписчикам этого пользователя."
            )
        } else if content.isLoadingTab {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 55)
        } else {
            switch selectedTab {
            case .posts:
                postsSection
            case .stories:
                storiesSection
            case .replies:
                repliesSection
            case .media:
                mediaSection
            case .gifts:
                giftsSection
            }
        }
    }

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Посты @\(username)")
                .font(.system(size: 21, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.top, 22)

            if content.posts.isEmpty {
                emptyState(
                    icon: "doc.text",
                    title: "Постов пока нет",
                    subtitle: "Опубликованные посты появятся здесь."
                )
            } else {
                ForEach(content.posts) { post in
                    ProfilePostCard(post: post)
                        .padding(.horizontal, 12)
                }

                loadMoreButton(tab: .posts, pageInfo: content.postsPageInfo)
            }
        }
    }

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if content.stories.isEmpty {
                emptyState(
                    icon: "sparkles.rectangle.stack",
                    title: "Историй пока нет",
                    subtitle: "Активные Stories пользователя появятся здесь."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ],
                    spacing: 4
                ) {
                    ForEach(content.stories) { story in
                        Button {
                            selectedStory = story
                            Task {
                                try? await UnixgramRealAPIClient.shared.markStoryViewed(storyId: story.id)
                            }
                        } label: {
                            ProfileStoryTile(story: story)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
        }
    }

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ответы @\(username)")
                .font(.system(size: 21, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.top, 22)

            if content.replies.isEmpty {
                emptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "У пользователя пока нет ответов.",
                    subtitle: "Новые ответы появятся здесь."
                )
            } else {
                ForEach(content.replies) { post in
                    ProfilePostCard(post: post)
                        .padding(.horizontal, 12)
                }

                loadMoreButton(tab: .replies, pageInfo: content.repliesPageInfo)
            }
        }
    }

    private var mediaSection: some View {
        Group {
            if content.media.isEmpty {
                emptyState(
                    icon: "photo.on.rectangle",
                    title: "Медиа пока нет",
                    subtitle: "Фото и видео из постов появятся здесь."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3),
                        GridItem(.flexible(), spacing: 3)
                    ],
                    spacing: 3
                ) {
                    ForEach(content.media) { post in
                        ProfileMediaTile(post: post)
                    }
                }
                .padding(.top, 3)

                loadMoreButton(tab: .media, pageInfo: content.mediaPageInfo)
            }
        }
    }

    private var giftsSection: some View {
        VStack(spacing: 14) {
            if content.gifts.isEmpty {
                emptyState(
                    icon: "gift",
                    title: "Подарков пока нет",
                    subtitle: "Полученные подарки Unixgram появятся здесь."
                )
            } else {
                HStack {
                    Text(isOwnProfile ? "Мои подарки" : "Подарки @\(username)")
                        .font(.system(size: 19, weight: .bold))
                    Spacer()
                    Text("\(content.gifts.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 12
                ) {
                    ForEach(content.gifts) { gift in
                        Button {
                            selectedGift = gift
                        } label: {
                            ProfileGiftCard(gift: gift)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func loadMoreButton(tab: UnixgramProfileTab, pageInfo: UGProfilePageInfo?) -> some View {
        if pageInfo?.hasMore == true {
            Button {
                Task {
                    await content.loadMore(tab: tab, username: username)
                }
            } label: {
                Text("Загрузить ещё")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 18, weight: .bold))

            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.vertical, 72)
    }

    // MARK: Helpers

    private func stat(_ value: Int?, _ title: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value ?? 0)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(premiumAccent ?? Color.white)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
    }

    private func metadata(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
    }

    private func circleActionButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.58))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12)))
        }
    }

    @ViewBuilder
    private func cover(url raw: String?) -> some View {
        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    coverFallback
                }
            }
        } else {
            coverFallback
        }
    }

    private var coverFallback: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.16, blue: 0.14),
                Color(red: 0.15, green: 0.07, blue: 0.07),
                .black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func avatar(url raw: String?, name: String) -> some View {
        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarFallback(name)
                }
            }
        } else {
            avatarFallback(name)
        }
    }

    private func avatarFallback(_ name: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 42, weight: .bold))
            }
    }

    private func cleanedWebsite(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private func normalizedWebsiteURL(_ raw: String) -> URL? {
        if raw.hasPrefix("https://") || raw.hasPrefix("http://") {
            return URL(string: raw)
        }
        return URL(string: "https://\(raw)")
    }

    private func friendlyDate(_ raw: String) -> String {
        guard let date = unixgramDate(raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func lastSeen(_ raw: String?) -> String {
        guard let raw else { return "Не в сети" }
        guard let date = unixgramDate(raw) else { return "Был(а) в сети недавно" }
        return "Был(а) в сети \(date.formatted(.relative(presentation: .named)))"
    }

    private func unixgramDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: raw)
    }

    private func linkIcon(_ platform: String?) -> String {
        switch platform?.lowercased() {
        case "telegram": "paperplane.fill"
        case "youtube": "play.rectangle.fill"
        case "github": "chevron.left.forwardslash.chevron.right"
        case "soundcloud": "waveform"
        case "website": "globe"
        default: "link"
        }
    }

    private func dayWord(_ value: Int) -> String {
        let mod10 = value % 10
        let mod100 = value % 100
        if mod10 == 1, mod100 != 11 { return "день" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "дня" }
        return "дней"
    }
}

// MARK: - Music strip

private struct ProfileMusicStrip: View {
    let music: UGProfileMusic

    var body: some View {
        UnixgramMusicRow(track: UnixgramMusicTrack(music), compact: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

// MARK: - Post card

private struct ProfilePostCard: View {
    let post: UGHARFeedPost

    @State private var selectedMedia: UnixgramMediaViewerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                avatar
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.author?.displayName ?? post.author?.username ?? "Unixgram")
                            .font(.system(size: 15, weight: .bold))

                        if let username = post.author?.username {
                            Text("@\(username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let created = post.createdAt {
                            Text("· \(shortDate(created))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let community = post.community?.name {
                        Text(community)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }

            if let content = post.content, !content.isEmpty {
                UnixgramMentionText(
                    text: content,
                    font: .system(size: 16),
                    color: .white
                )
            }

            postMedia

            if let music = post.music {
                UnixgramMusicRow(track: UnixgramMusicTrack(music))
            }

            UnixgramPostInteractionBar(
                post: post,
                showViews: true,
                showBookmark: true
            )
        }
        .padding(14)
        .background(Color(red: 0.055, green: 0.055, blue: 0.066))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .fullScreenCover(item: $selectedMedia) { item in
            UnixgramMediaViewer(item: item)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let raw = post.author?.avatarUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Circle().fill(Color.white.opacity(0.08))
                }
            }
        } else {
            Circle().fill(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var postMedia: some View {
        let images = ([post.imageUrl].compactMap { $0 } + (post.imageUrls ?? [])).uniqueMediaURLs()

        if !images.isEmpty {
            LazyVGrid(
                columns: images.count == 1
                    ? [GridItem(.flexible())]
                    : [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 4
            ) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, raw in
                    AsyncImage(url: URL(string: raw)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .overlay(ProgressView())
                        }
                    }
                    .frame(height: images.count == 1 ? 300 : 165)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: raw) {
                            selectedMedia = UnixgramMediaViewerItem(url: url, kind: .image)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else if let raw = post.videoUrl, let url = URL(string: raw) {
            UnixgramVideoThumbnailView(videoURL: url, cornerRadius: 14)
                .frame(height: 260)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMedia = UnixgramMediaViewerItem(url: url, kind: .video)
                }
        }
    }

    private func metric(_ icon: String, _ value: Int?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            if let value, value > 0 {
                Text("\(value)")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private func shortDate(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Story

private struct ProfileStoryTile: View {
    let story: UGProfileStory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            media
                .aspectRatio(0.68, contentMode: .fill)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            if let music = story.music {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                    Text(music.title ?? "Музыка")
                        .lineLimit(1)
                }
                .font(.caption2.bold())
                .padding(7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var media: some View {
        let raw = story.previewUrl ?? story.thumbnailUrl ?? story.imageUrl

        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Rectangle().fill(Color.white.opacity(0.06))
                }
            }
        } else {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    if story.videoUrl != nil {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                }
        }
    }
}

struct ProfileStoryViewer: View {
    @Environment(\.dismiss) private var dismiss
    let story: UGProfileStory

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let rawVideo = story.videoUrl, let videoURL = URL(string: rawVideo) {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .ignoresSafeArea()
            } else if let raw = story.imageUrl ?? story.previewUrl ?? story.thumbnailUrl,
                      let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        ProgressView()
                    }
                }
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 68))
                    .foregroundStyle(.secondary)
            }

            if let music = story.music {
                VStack {
                    Spacer()
                    UnixgramMusicRow(track: UnixgramMusicTrack(music), compact: true)
                        .padding(.horizontal, 18)
                        .padding(.bottom, story.text?.isEmpty == false ? 88 : 28)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .foregroundStyle(.white)
                }
                .padding(18)

                Spacer()

                if let text = story.text, !text.isEmpty {
                    Text(text)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .padding(18)
                }
            }
        }
    }
}

// MARK: - Media

private struct ProfileMediaTile: View {
    let post: UGHARFeedPost

    @State private var selectedMedia: UnixgramMediaViewerItem?

    var body: some View {
        ZStack {
            if let raw = firstImage, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color.white.opacity(0.06))
                    }
                }
            } else if let rawVideo = post.videoUrl, let videoURL = URL(string: rawVideo) {
                UnixgramVideoThumbnailView(videoURL: videoURL, cornerRadius: 0)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .overlay {
                        Image(systemName: "photo")
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if let raw = post.videoUrl, let url = URL(string: raw) {
                selectedMedia = UnixgramMediaViewerItem(url: url, kind: .video)
            } else if let raw = firstImage, let url = URL(string: raw) {
                selectedMedia = UnixgramMediaViewerItem(url: url, kind: .image)
            }
        }
        .fullScreenCover(item: $selectedMedia) { item in
            UnixgramMediaViewer(item: item)
        }
    }

    private var firstImage: String? {
        post.imageUrl ?? post.imageUrls?.first ?? post.imageThumbs?.first
    }
}

// MARK: - Gift

private struct ProfileGiftCard: View {
    let gift: UGProfileGift

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.20), .blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let raw = gift.modelPngUrl ?? gift.templateImageUrl,
                   let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            ProgressView()
                        }
                    }
                    .padding(14)
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                }
            }
            .frame(height: 160)

            Text(gift.title ?? gift.collectionName ?? "Подарок")
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)

            if let serial = gift.serial {
                Text("#\(serial)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}


private struct ProfileGiftDetailSheet: View {
    let gift: UGProfileGift

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 54, height: 5)
                .padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.24), .blue.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let raw = gift.modelPngUrl ?? gift.templateImageUrl,
                   let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            ProgressView()
                        }
                    }
                    .padding(22)
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.purple)
                }
            }
            .frame(height: 230)

            Text(gift.title ?? gift.collectionName ?? "Подарок")
                .font(.system(size: 25, weight: .bold))

            HStack(spacing: 10) {
                if let collection = gift.collectionName, !collection.isEmpty {
                    badge(collection)
                }
                if let serial = gift.serial {
                    badge("#\(serial)")
                }
                if let price = gift.price {
                    badge("\(price.formatted()) ⭐")
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Закрыть")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 17))
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
    }
}


private extension Array where Element == String {
    func uniqueMediaURLs() -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in self {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Unixgram can expose the same attachment both as `imageUrl`
            // and as the first element of `imageUrls`. Treat those as one
            // media item instead of rendering a fake two-photo grid.
            let key: String
            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               let host = url.host?.lowercased() {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = scheme
                components?.host = host
                components?.fragment = nil
                key = components?.string ?? trimmed
            } else {
                key = trimmed
            }

            if seen.insert(key).inserted {
                result.append(trimmed)
            }
        }
        return result
    }
}
