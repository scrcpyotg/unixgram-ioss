import SwiftUI

struct UnixgramAllRealFeedView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    @State private var loadingMore = false
    @State private var showCreatePost = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                liveStoriesHeader
                realComposer

                if store.feed.isEmpty && !store.isRefreshing {
                    empty
                }

                ForEach(Array(store.feed.enumerated()), id: \.element.id) { index, post in
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

                            if index >= store.feed.count - 3 {
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
        .navigationTitle("Главная")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.feed.isEmpty {
                await store.refreshFeed()
            }

            // Load the rest after the main timeline is already available.
            Task {
                await store.refreshAll()
            }
        }
        .refreshable {
            await store.refreshFeed()
            Task {
                await store.refreshAll()
            }
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
                                    colors: [.purple, .pink, .orange],
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

private struct HARFeedPostCard: View {
    let post: UGHARFeedPost

    @State private var selectedMedia: UnixgramMediaViewerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(post.author?.displayName ?? post.author?.username ?? post.community?.name ?? "Unixgram")
                            .font(.system(size: 16, weight: .bold))
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
                showBookmark: true
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
                ForEach(Array(urls.prefix(4).enumerated()), id: \.offset) { _, raw in
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
            RoundedRectangle(cornerRadius: 16)
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
        guard let date = parser.date(from: raw) else { return "" }
        return date.formatted(.relative(presentation: .numeric))
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
