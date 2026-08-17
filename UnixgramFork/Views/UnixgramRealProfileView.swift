import SwiftUI
import AVKit

struct UnixgramRealProfileView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @EnvironmentObject private var dashboard: UnixgramLiveDashboardStore

    @StateObject private var content = UnixgramProfileContentStore()
    @State private var selectedTab: UnixgramProfileTab = .posts
    @State private var showSettings = false
    @State private var showCreatePost = false
    @State private var selectedStory: UGProfileStory?

    private var username: String {
        content.profile?.username ?? liveSession.currentUser?.username ?? ""
    }

    var body: some View {
        Group {
            if let account = liveSession.currentUser {
                profileBody(account)
            } else {
                ProgressView("Загружаем профиль…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if liveSession.currentUser == nil {
                await liveSession.refreshAuthentication()
            }

            guard !username.isEmpty else { return }
            await content.refresh(username: username, selectedTab: selectedTab)
        }
        .onChange(of: selectedTab) {
            guard !username.isEmpty else { return }
            Task {
                await content.load(tab: selectedTab, username: username)
            }
        }
        .sheet(isPresented: $showSettings) {
            if let user = liveSession.currentUser {
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
        .fullScreenCover(item: $selectedStory) { story in
            ProfileStoryViewer(story: story)
        }
    }

    private func profileBody(_ account: UGCurrentAccount) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                profileHeader(account)
                profileTabs
                    .background(Color.black)
                tabContent(account)
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

    private func profileHeader(_ account: UGCurrentAccount) -> some View {
        let profile = content.profile

        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                cover(url: profile?.coverUrl ?? account.coverUrl)
                    .frame(height: 285)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.55), .clear, Color.black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack {
                    circleButton("chevron.left")
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(profile?.displayName ?? account.displayName ?? account.username)
                            .font(.system(size: 20, weight: .bold))
                        Text("\(profile?.postsCount ?? content.posts.count) постов")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    circleButton("qrcode")
                }
                .padding(.horizontal, 18)
                .padding(.top, 15)
            }

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top) {
                    avatar(url: profile?.avatarUrl ?? account.avatarUrl, name: profile?.displayName ?? account.displayName ?? account.username)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.black, lineWidth: 4))
                        .offset(y: -59)

                    Spacer()

                    Button("Редактировать") {
                        showSettings = true
                    }
                    .font(.system(size: 17, weight: .bold))
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(Color.black)
                    .overlay(Capsule().stroke(Color.white.opacity(0.14)))
                    .clipShape(Capsule())

                    Button {
                        showCreatePost = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.58))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12)))
                    }
                    .accessibilityLabel("Создать пост")

                    circleButton("sparkles")
                    circleButton("gift")
                }
                .padding(.bottom, -59)

                HStack(spacing: 7) {
                    Text(profile?.displayName ?? account.displayName ?? account.username)
                        .font(.system(size: 27, weight: .bold))

                    if let badge = profile?.verificationBadge ?? account.verificationBadge,
                       badge != "NONE" {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                    }

                    if let number = profile?.registrationNumber ?? account.registrationNumber {
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

                Text("@\(profile?.username ?? account.username)")
                    .font(.system(size: 19))
                    .foregroundStyle(.secondary)

                HStack(spacing: 7) {
                    Circle()
                        .fill(profile?.isOnline == false ? Color.secondary : Color.green)
                        .frame(width: 9, height: 9)

                    Text(profile?.isOnline == false ? lastSeen(profile?.lastSeenAt) : "В сети")
                        .foregroundStyle(profile?.isOnline == false ? Color.secondary : Color.green)
                }
                .font(.system(size: 16))

                if let aliases = profile?.usernameAliases ?? account.usernameAliases,
                   !aliases.isEmpty {
                    (
                        Text("а также ")
                            .foregroundStyle(.secondary)
                        +
                        Text(aliases.map { "@\($0)" }.joined(separator: ", "))
                            .foregroundStyle(.blue)
                    )
                    .font(.system(size: 16))
                }

                if let bio = profile?.bio ?? account.bio,
                   !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 17))
                }

                HStack(spacing: 14) {
                    if let location = profile?.location ?? account.location,
                       !location.isEmpty {
                        metadata("location", location)
                    }

                    if let website = profile?.website ?? account.website,
                       !website.isEmpty {
                        metadata("link", cleanedWebsite(website))
                    }
                }

                if let created = profile?.createdAt ?? account.createdAt {
                    metadata("calendar", "На Unixgram с \(friendlyDate(created))")
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
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)

                            Capsule()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
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
    private func tabContent(_ account: UGCurrentAccount) -> some View {
        if content.isLoadingTab {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 55)
        } else {
            switch selectedTab {
            case .posts:
                postsSection(account)
            case .stories:
                storiesSection
            case .replies:
                repliesSection(account)
            case .media:
                mediaSection
            case .gifts:
                giftsSection
            }
        }
    }

    private func postsSection(_ account: UGCurrentAccount) -> some View {
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

    private func repliesSection(_ account: UGCurrentAccount) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ответы @\(username)")
                .font(.system(size: 21, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.top, 22)

            if content.replies.isEmpty {
                emptyState(
                    icon: "bubble.left.and.bubble.right",
                    title: "У пользователя пока нет ответов.",
                    subtitle: "Подпишитесь, чтобы не пропустить новые."
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
        Group {
            if content.gifts.isEmpty {
                emptyState(
                    icon: "gift",
                    title: "Подарков пока нет",
                    subtitle: "Полученные подарки Unixgram появятся здесь."
                )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 12
                ) {
                    ForEach(content.gifts) { gift in
                        ProfileGiftCard(gift: gift)
                    }
                }
                .padding(14)
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
                .foregroundStyle(.white)
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

    private func circleButton(_ icon: String) -> some View {
        Button {} label: {
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

    private func friendlyDate(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func lastSeen(_ raw: String?) -> String {
        guard let raw else { return "Не в сети" }
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return "Был(а) в сети недавно" }
        return "Был(а) в сети \(date.formatted(.relative(presentation: .named)))"
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
                ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { _, raw in
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
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .frame(height: 260)
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                }
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
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .overlay {
                        Image(systemName: post.videoUrl != nil ? "play.fill" : "photo")
                    }
            }

            if post.videoUrl != nil {
                Image(systemName: "play.fill")
                    .font(.title3)
                    .shadow(radius: 8)
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
