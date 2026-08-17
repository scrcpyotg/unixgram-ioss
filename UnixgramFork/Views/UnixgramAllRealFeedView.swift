import SwiftUI

struct UnixgramAllRealFeedView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @StateObject private var commerce = UnixgramCommerceStore.shared

    @AppStorage("unixgram.feed.showSshkmGskm") private var showSshkmGskm = false

    @State private var loadingMore = false
    @State private var showCreatePost = false
    @State private var feedMode: FeedMode = .forYou

    private enum FeedMode: String, CaseIterable, Identifiable {
        case forYou = "Для вас"
        case following = "Подписки"
        case tags = "Теги"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                homeHeader
                feedSelector
                contentFilter
                liveStoriesHeader
                realComposer

                if visibleFeed.isEmpty && !store.isRefreshing {
                    emptyForCurrentMode
                }

                ForEach(Array(visibleFeed.enumerated()), id: \.element.id) { index, post in
                    HARFeedPostCard(post: post)
                        .onAppear {
                            Task {
                                try? await UnixgramRealAPIClient.shared.markPostViewed(postId: post.id)
                                try? await UnixgramRealAPIClient.shared.sendFeedViewSignal(
                                    postId: post.id,
                                    dwellMs: 1200,
                                    visibleRatio: 0.92,
                                    completed: false
                                )
                            }

                            if index >= visibleFeed.count - 3 {
                                Task { await loadMore() }
                            }
                        }
                }

                if loadingMore {
                    ProgressView().padding(.vertical, 22)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 30)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if store.feed.isEmpty {
                await store.refreshFeed()
            }

            await commerce.refreshStars(fallback: liveSession.currentUser)

            Task {
                await store.refreshAll()
            }
        }
        .refreshable {
            liveSession.showRefreshingNotice()
            await store.refreshFeed()
            if store.feedErrorMessage != nil {
                liveSession.showOfflineNotice()
            } else {
                liveSession.hideNotice(after: 0.5)
            }
            Task {
                await store.refreshAll()
            }
            Task {
                await commerce.refreshStars(fallback: liveSession.currentUser)
            }
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 12) {
            Text("Unixgram")
                .font(.system(size: 27, weight: .bold))

            Spacer()

            NavigationLink {
                UnixgramAllRealStarsView()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                    Text(starsText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
        .padding(.horizontal, 2)
    }

    private var feedSelector: some View {
        HStack(spacing: 4) {
            ForEach(FeedMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { feedMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(feedMode == mode ? .white : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Capsule()
                                .fill(feedMode == mode ? Color.purple.opacity(0.20) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.045))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var contentFilter: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showSshkmGskm.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showSshkmGskm ? "eye" : "eye.slash")
                    .font(.system(size: 13, weight: .semibold))

                Text(showSshkmGskm ? "СШКМ/ГСКМ показываются" : "СШКМ/ГСКМ скрыты")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text(showSshkmGskm ? "Скрыть" : "Показать")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.purple)
            }
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var starsText: String {
        if let balance = commerce.starsBalance ?? liveSession.currentUser?.resolvedStarsBalance {
            return String(balance)
        }
        return commerce.isRefreshingStars ? "…" : "—"
    }

    private var visibleFeed: [UGHARFeedPost] {
        let modeFeed: [UGHARFeedPost]

        switch feedMode {
        case .forYou:
            modeFeed = store.feed
        case .following:
            modeFeed = store.feed.filter { $0.author?.isFollowing == true }
        case .tags:
            modeFeed = store.feed.filter { post in
                guard let content = post.content else { return false }
                return content.split(whereSeparator: { $0.isWhitespace }).contains { token in
                    token.hasPrefix("#") && token.count > 1
                }
            }
        }

        guard !showSshkmGskm else { return modeFeed }
        return modeFeed.filter { !containsMutedTag($0.content) }
    }

    private func containsMutedTag(_ content: String?) -> Bool {
        guard let content, !content.isEmpty else { return false }

        let pattern = #"(?iu)(?<![\p{L}\p{N}_])#(?:сшкм|гскм)(?![\p{L}\p{N}_])"#
        return content.range(of: pattern, options: .regularExpression) != nil
    }

    private var emptyForCurrentMode: some View {
        VStack(spacing: 12) {
            Image(systemName: feedMode == .following ? "person.2" : (feedMode == .tags ? "number" : "rectangle.stack"))
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(emptyTitle)
                .font(.headline)

            if !showSshkmGskm && store.feed.contains(where: { containsMutedTag($0.content) }) {
                Button("Показать скрытые посты") {
                    showSshkmGskm = true
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }

            if let error = store.feedErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Повторить") { Task { await store.refreshFeed() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyTitle: String {
        if store.feedErrorMessage != nil { return "Не удалось загрузить ленту" }

        if !showSshkmGskm,
           !store.feed.isEmpty,
           visibleFeed.isEmpty,
           store.feed.contains(where: { containsMutedTag($0.content) }) {
            return "Все посты в этой ленте скрыты фильтром"
        }

        switch feedMode {
        case .forYou: return "В ленте пока нет постов"
        case .following: return "Нет постов от ваших подписок"
        case .tags: return "В загруженной ленте пока нет постов с тегами"
        }
    }

    private var liveStoriesHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    avatar(url: liveSession.currentUser?.avatarUrl)
                        .frame(width: 66, height: 66)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                                .foregroundStyle(.black)
                                .frame(width: 22, height: 22)
                                .background(.white)
                                .clipShape(Circle())
                        }
                    Text("Ваша история")
                        .font(.caption2)
                }

                ForEach(uniqueAuthors.prefix(10)) { author in
                    VStack(spacing: 6) {
                        avatar(url: author.avatarUrl)
                            .frame(width: 66, height: 66)
                            .overlay(Circle().stroke(
                                LinearGradient(
                                    colors: [.purple, .indigo, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            ))
                        Text(author.displayName ?? author.username)
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(width: 72)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var realComposer: some View {
        Button {
            showCreatePost = true
        } label: {
            HStack(spacing: 12) {
                avatar(url: liveSession.currentUser?.avatarUrl)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Что нового?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Создать пост")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 66)
            .background(Color.white.opacity(0.035))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCreatePost) {
            UnixgramCreatePostView {
                Task { await store.refreshFeed() }
            }
            .environmentObject(liveSession)
            .environmentObject(store)
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(store.feedErrorMessage == nil ? "В ленте пока нет постов" : "Не удалось загрузить ленту")
                .font(.headline)

            if let error = store.feedErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 22)

                Button("Повторить") {
                    Task { await store.refreshFeed() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding(.vertical, 60)
    }

    private var uniqueAuthors: [UGHARFeedAuthor] {
        var seen = Set<String>()
        return store.feed.compactMap(\.author).filter { seen.insert($0.id).inserted }
    }

    private func loadMore() async {
        guard !loadingMore, store.feedHasMore else { return }

        loadingMore = true
        defer { loadingMore = false }

        await store.appendNextFeedPage()
    }

    private func avatar(url raw: String?) -> some View {
        Group {
            if let raw, let url = URL(string: raw) {
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
        .clipShape(Circle())
    }
}

struct HARFeedPostCard: View {
    let post: UGHARFeedPost
    var openCommentsInitially: Bool = false

    @State private var selectedMedia: UnixgramMediaViewerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                if let username = post.author?.username, !username.isEmpty {
                    NavigationLink {
                        UnixgramPublicProfileView(username: username)
                    } label: {
                        avatar
                    }
                    .buttonStyle(.plain)
                } else {
                    avatar
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if let username = post.author?.username, !username.isEmpty {
                            NavigationLink {
                                UnixgramPublicProfileView(username: username)
                            } label: {
                                Text(post.author?.displayName ?? username)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(post.author?.displayName ?? post.community?.name ?? "Unixgram")
                                .font(.system(size: 16, weight: .bold))
                        }
                        if post.author?.verificationBadge != "NONE" || post.community?.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.cyan)
                                .font(.caption)
                        }
                        if post.author?.premium == true {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                                .font(.caption)
                        }
                    }

                    HStack(spacing: 5) {
                        if let username = post.author?.username {
                            Text("@\(username)")
                        } else if let handle = post.community?.handle {
                            Text("@\(handle)")
                        }

                        if let created = post.createdAt {
                            Text("• \(relative(created))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }

            if let content = post.content, !content.isEmpty {
                UnixgramMentionText(
                    text: content,
                    font: .system(size: 16),
                    color: .white
                )
            }

            media

            if let music = post.music {
                UnixgramMusicRow(track: UnixgramMusicTrack(music))
            }

            if let poll = post.poll {
                VStack(alignment: .leading, spacing: 9) {
                    if let question = poll.question {
                        Text(question).font(.headline)
                    }
                    ForEach(poll.options ?? []) { option in
                        HStack {
                            Text(option.text)
                            Spacer()
                            if let votes = option.votes {
                                Text("\(votes)").foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 46)
                        .background(Color.white.opacity(option.selectedByViewer == true ? 0.09 : 0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            UnixgramPostInteractionBar(
                post: post,
                showViews: true,
                showBookmark: true,
                openCommentsInitially: openCommentsInitially
            )
        }
        .padding(14)
        .background(Color.white.opacity(0.035))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.075)))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .fullScreenCover(item: $selectedMedia) { item in
            UnixgramMediaViewer(item: item)
        }
    }

    @ViewBuilder
    private var media: some View {
        let urls = ([post.imageUrl].compactMap { $0 } + (post.imageUrls ?? [])).uniqueMediaURLs()
        if !urls.isEmpty {
            LazyVGrid(
                columns: urls.count == 1 ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 6
            ) {
                ForEach(Array(urls.enumerated()), id: \.offset) { _, raw in
                    AsyncImage(url: URL(string: raw)) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Rectangle().fill(Color.white.opacity(0.05)).overlay(ProgressView())
                        }
                    }
                    .frame(height: urls.count == 1 ? 300 : 175)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: raw) {
                            selectedMedia = UnixgramMediaViewerItem(url: url, kind: .image)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let raw = post.videoUrl, let url = URL(string: raw) {
            UnixgramVideoThumbnailView(videoURL: url, cornerRadius: 16)
                .frame(height: 260)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMedia = UnixgramMediaViewerItem(url: url, kind: .video)
                }
        }
    }

    private var avatar: some View {
        Group {
            let raw = post.author?.avatarUrl ?? post.community?.avatarUrl
            if let raw, let url = URL(string: raw) {
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
        .frame(width: 46, height: 46)
        .clipShape(Circle())
    }

    private func stat(_ icon: String, _ value: Int?, _ tint: Color = .secondary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            if let value, value > 0 {
                Text("\(value)")
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(tint)
    }

    private func relative(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: raw)
        if date == nil {
            parser.formatOptions = [.withInternetDateTime]
            date = parser.date(from: raw)
        }
        guard let date else { return "" }

        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 45 { return "сейчас" }
        if seconds < 3_600 { return "\(seconds / 60) мин." }
        if seconds < 86_400 { return "\(seconds / 3_600) ч." }
        if seconds < 604_800 { return "\(seconds / 86_400) д." }
        if seconds < 2_592_000 { return "\(seconds / 604_800) нед." }
        if seconds < 31_536_000 { return "\(seconds / 2_592_000) мес." }
        return "\(seconds / 31_536_000) г."
    }
}

private extension Array where Element == String {
    func uniqueMediaURLs() -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in self {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

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
