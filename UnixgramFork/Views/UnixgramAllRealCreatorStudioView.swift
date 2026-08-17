import SwiftUI

struct UnixgramAllRealCreatorStudioView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @StateObject private var studio = UnixgramCreatorStudioStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Студия автора")
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    if studio.isLoading {
                        ProgressView().tint(.purple)
                    }
                }

                profileCard
                metricGrid

                if let error = studio.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Ваши каналы")
                    .font(.system(size: 22, weight: .bold))

                if store.adminedCommunities.isEmpty {
                    Text("Каналов пока нет")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.adminedCommunities) { channel in
                        NavigationLink {
                            UnixgramOwnedChannelView(channel: channel)
                                .environmentObject(store)
                                .environmentObject(liveSession)
                        } label: {
                            channelRow(channel)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Черновики")
                    .font(.system(size: 22, weight: .bold))

                if store.drafts.isEmpty {
                    Text("Черновиков нет")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.drafts) { draft in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(draft.content ?? "Черновик")
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(2)
                            Text(draft.type ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .task { await reload(force: false) }
        .refreshable { await reload(force: true) }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            avatar(studio.profile?.avatarUrl ?? liveSession.currentUser?.avatarUrl, size: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(studio.profile?.displayName ?? liveSession.currentUser?.displayName ?? liveSession.currentUser?.username ?? "Unixgram")
                    .font(.system(size: 19, weight: .bold))
                Text("@\(studio.profile?.username ?? liveSession.currentUser?.username ?? "")")
                    .foregroundStyle(.secondary)
                Text(liveSession.currentUser?.premium == true ? "Unix Premium" : "Автор Unixgram")
                    .font(.caption.bold())
                    .foregroundStyle(liveSession.currentUser?.premium == true ? Color.purple : Color.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metric("Посты", studio.postsCount, "doc.text")
            metric("Просмотры", studio.viewsCount, "eye")
            metric("Уник. просмотры", studio.uniqueViewsCount, "person.crop.circle.badge.checkmark")
            metric("Лайки", studio.likesCount, "heart")
            metric("Комментарии", studio.commentsCount, "bubble.left")
            metric("Репосты", studio.repostsCount, "arrow.2.squarepath")
            metric("Сохранения", studio.bookmarksCount, "bookmark")
            metric("Подписчики", studio.followersCount, "person.2")
            metric("Подписки", studio.followingCount, "person.badge.plus")
            metric("Stories", studio.storiesCount, "circle.dashed")
        }
    }

    private func metric(_ title: String, _ value: Int, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.purple)
            Text(value.formatted())
                .font(.system(size: 28, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func channelRow(_ channel: UGAdminedCommunityDTO) -> some View {
        HStack(spacing: 12) {
            avatar(channel.avatarUrl, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(channel.name).font(.headline).foregroundStyle(.white)
                    if channel.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.cyan)
                            .font(.caption)
                    }
                }
                Text("@\(channel.handle)")
                    .foregroundStyle(.secondary)
                if let count = channel.subscribersCount {
                    Text("\(count) подписчиков")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func avatar(_ raw: String?, size: CGFloat) -> some View {
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
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @MainActor
    private func reload(force: Bool) async {
        if force || store.adminedCommunities.isEmpty {
            await store.refreshAll()
        }
        if let username = liveSession.currentUser?.username {
            await studio.load(username: username, force: force)
        }
    }
}

struct UnixgramOwnedChannelView: View {
    let channel: UGAdminedCommunityDTO

    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var showComposer = false

    private var fullCommunity: UGCommunityDTO? {
        store.communities.first { item in
            item.id == channel.id || item.handle.caseInsensitiveCompare(channel.handle) == .orderedSame
        }
    }

    private var channelPosts: [UGHARFeedPost] {
        store.feed.filter { post in
            guard let community = post.community else { return false }
            return community.id == channel.id || community.handle.caseInsensitiveCompare(channel.handle) == .orderedSame
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                channelHeader

                HStack {
                    Text("Посты канала")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Text("\(fullCommunity?.postsCount ?? channelPosts.count)")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)

                if channelPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("В загруженной ленте пока нет постов этого канала")
                            .font(.headline)
                        Text("Новый пост можно опубликовать прямо отсюда.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    ForEach(channelPosts) { post in
                        HARFeedPostCard(post: post)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showComposer = true } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            UnixgramCreatePostView(
                communityId: channel.id,
                communityName: channel.name,
                communityHandle: channel.handle,
                communityAvatarURL: channel.avatarUrl
            ) {
                Task { await store.refreshFeed() }
            }
            .environmentObject(liveSession)
            .environmentObject(store)
        }
        .refreshable { await store.refreshAll() }
    }

    private var channelHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                avatar
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(.system(size: 25, weight: .bold))
                        if channel.verified == true {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.cyan)
                        }
                    }
                    Text("@\(channel.handle)")
                        .foregroundStyle(.secondary)
                    if let subscribers = channel.subscribersCount {
                        Text("\(subscribers) подписчиков")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let description = fullCommunity?.description, !description.isEmpty {
                Text(description)
            }

            Button { showComposer = true } label: {
                Label("Новый пост в канал", systemImage: "square.and.pencil")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.white.opacity(0.025))
    }

    @ViewBuilder
    private var avatar: some View {
        if let raw = channel.avatarUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Circle().fill(Color.purple.opacity(0.18))
                }
            }
        } else {
            Circle().fill(Color.purple.opacity(0.18))
                .overlay(Image(systemName: "megaphone.fill").foregroundStyle(.purple))
        }
    }
}
