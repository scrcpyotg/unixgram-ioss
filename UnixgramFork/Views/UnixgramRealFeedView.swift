import SwiftUI

struct UnixgramRealFeedView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    @State private var posts: [UGFeedPost] = []
    @State private var nextCursor: String?
    @State private var isLoading = false
    @State private var loadingMore = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading && posts.isEmpty {
                ProgressView("Загружаем ленту…")
            } else if posts.isEmpty {
                emptyState
            } else {
                feedList
            }
        }
        .navigationTitle("Главная")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if posts.isEmpty {
                await reload()
            }
        }
        .refreshable {
            await reload()
        }
        .alert("Ошибка ленты", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                storiesStrip

                composerStub

                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    RealFeedPostCard(post: post) { signal, value in
                        Task { await sendSignal(post: post, signal: signal, value: value) }
                    }
                    .onAppear {
                        if index >= posts.count - 3 {
                            Task { await loadMoreIfNeeded() }
                        }
                    }
                }

                if loadingMore {
                    ProgressView()
                        .padding(.vertical, 24)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var storiesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StoryCircle(title: "Ваша история", systemImage: "plus")

                ForEach(posts.compactMap { $0.author }.uniqueByID().prefix(10)) { author in
                    StoryAvatarCircle(author: author)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var composerStub: some View {
        HStack(spacing: 12) {
            Group {
                if let user = liveSession.currentUser,
                   let raw = user.avatarUrl,
                   let url = URL(string: raw) {
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
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            Text("Что нового?")
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
        .background(Color.white.opacity(0.035))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Лента пуста")
                .font(.title3.bold())

            Button("Обновить") {
                Task { await reload() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await UnixgramRealAPIClient.shared.feed(limit: 15)
            posts = result.posts
            nextCursor = result.nextCursor
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMoreIfNeeded() async {
        guard !loadingMore, let cursor = nextCursor, !cursor.isEmpty else { return }
        loadingMore = true
        defer { loadingMore = false }

        do {
            let result = try await UnixgramRealAPIClient.shared.feed(limit: 15, cursor: cursor)
            let existing = Set(posts.map(\.id))
            posts.append(contentsOf: result.posts.filter { !existing.contains($0.id) })
            nextCursor = result.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendSignal(post: UGFeedPost, signal: String, value: Bool?) async {
        do {
            try await UnixgramRealAPIClient.shared.sendFeedSignal(
                postId: post.id,
                signal: signal,
                value: value
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RealFeedPostCard: View {
    let post: UGFeedPost
    let onSignal: (String, Bool?) -> Void

    @State private var liked: Bool
    @State private var bookmarked: Bool

    init(post: UGFeedPost, onSignal: @escaping (String, Bool?) -> Void) {
        self.post = post
        self.onSignal = onSignal
        _liked = State(initialValue: post.viewer?.liked ?? false)
        _bookmarked = State(initialValue: post.viewer?.bookmarked ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 16))
                    .textSelection(.enabled)
            }

            if let media = post.media, !media.isEmpty {
                mediaGrid(media)
            }

            if let poll = post.poll {
                pollView(poll)
            }

            HStack(spacing: 18) {
                actionButton(
                    icon: liked ? "heart.fill" : "heart",
                    title: count(post.stats?.likes),
                    tint: liked ? Color.pink : Color.secondary
                ) {
                    liked.toggle()
                    onSignal("like", liked)
                }

                actionButton(
                    icon: "bubble.left",
                    title: count(post.stats?.comments)
                ) {
                    onSignal("open_comments", nil)
                }

                actionButton(
                    icon: "arrow.2.squarepath",
                    title: count(post.stats?.reposts)
                ) {
                    onSignal("repost", true)
                }

                Spacer()

                actionButton(
                    icon: bookmarked ? "bookmark.fill" : "bookmark",
                    title: ""
                ) {
                    bookmarked.toggle()
                    onSignal("bookmark", bookmarked)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.035))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.075)))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var header: some View {
        HStack(spacing: 11) {
            Group {
                if let raw = post.author?.avatarUrl, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Circle().fill(Color.white.opacity(0.08))
                        }
                    }
                } else if let raw = post.community?.avatarUrl, let url = URL(string: raw) {
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .bold))

                    if post.author?.verificationBadge != nil || post.community?.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .font(.caption)
                    }
                }

                HStack(spacing: 6) {
                    if let username = post.author?.username {
                        Text("@\(username)")
                    } else if let handle = post.community?.handle {
                        Text("@\(handle)")
                    }

                    if let date = post.createdAt {
                        Text("• \(relativeDate(date))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
        }
    }

    private var displayName: String {
        post.author?.displayName
        ?? post.author?.username
        ?? post.community?.name
        ?? "Unixgram"
    }

    private func mediaGrid(_ items: [UGFeedMedia]) -> some View {
        let first = items
        return LazyVGrid(
            columns: items.count == 1
                ? [GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 6
        ) {
            ForEach(Array(first.enumerated()), id: \.offset) { _, item in
                feedMedia(item)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func feedMedia(_ item: UGFeedMedia) -> some View {
        if let raw = item.previewUrl ?? item.url, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .overlay(ProgressView())
                }
            }
            .frame(height: post.media?.count == 1 ? 300 : 180)
            .clipped()
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 180)
                .overlay(Image(systemName: "photo"))
        }
    }

    private func pollView(_ poll: UGFeedPoll) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let question = poll.question {
                Text(question)
                    .font(.system(size: 17, weight: .bold))
            }

            ForEach(poll.options ?? []) { option in
                HStack {
                    Text(option.text)
                    Spacer()
                    if let votes = option.votes {
                        Text("\(votes)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.white.opacity(option.selectedByViewer == true ? 0.09 : 0.035))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08)))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func actionButton(
        icon: String,
        title: String,
        tint: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                if !title.isEmpty {
                    Text(title)
                }
            }
            .foregroundStyle(tint)
            .font(.system(size: 15, weight: .semibold))
        }
    }

    private func count(_ value: Int?) -> String {
        guard let value, value > 0 else { return "" }
        return value >= 1000 ? String(format: "%.1fK", Double(value) / 1000.0) : "\(value)"
    }

    private func relativeDate(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return "" }
        return date.formatted(.relative(presentation: .numeric))
    }
}

private struct StoryCircle: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 68, height: 68)
                .overlay {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .padding(5)
                        .overlay(Image(systemName: systemImage))
                }

            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 72)
        }
    }
}

private struct StoryAvatarCircle: View {
    let author: UGUserMini

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 68, height: 68)
                .overlay {
                    Group {
                        if let raw = author.avatarUrl, let url = URL(string: raw) {
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
                    .padding(5)
                    .clipShape(Circle())
                }

            Text(author.displayName ?? author.username ?? "user")
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 72)
        }
    }
}

private extension Array where Element == UGUserMini {
    func uniqueByID() -> [UGUserMini] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
