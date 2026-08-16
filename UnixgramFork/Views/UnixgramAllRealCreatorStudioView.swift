import SwiftUI

struct UnixgramAllRealCreatorStudioView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Студия автора")
                    .font(.system(size: 32, weight: .bold))

                premiumCard
                metricGrid

                Text("Ваши каналы")
                    .font(.system(size: 22, weight: .bold))

                ForEach(store.adminedCommunities) { channel in
                    HStack(spacing: 12) {
                        avatar(channel.avatarUrl)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(channel.name).font(.headline)
                            Text("@\(channel.handle)")
                                .foregroundStyle(.secondary)
                            if let count = channel.subscribersCount {
                                Text("\(count) подписчиков")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
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
        .task {
            if store.feed.isEmpty {
                await store.refreshAll()
            }
        }
        .refreshable {
            await store.refreshAll()
        }
    }

    private var premiumCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.purple)
                .frame(width: 58, height: 58)
                .background(Color.purple.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(liveSession.currentUser?.premium == true ? "Unix Premium активен" : "Обычный аккаунт")
                    .font(.system(size: 19, weight: .bold))
                Text("@\(liveSession.currentUser?.username ?? "")")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var metricGrid: some View {
        let ownPosts = store.feed.filter { $0.author?.isViewer == true }
        let views = ownPosts.compactMap(\.viewsCount).reduce(0, +)
        let likes = ownPosts.compactMap(\.likesCount).reduce(0, +)
        let comments = ownPosts.compactMap(\.commentsCount).reduce(0, +)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metric("Посты в текущей ленте", "\(ownPosts.count)", "doc.text")
            metric("Просмотры", "\(views)", "eye")
            metric("Лайки", "\(likes)", "heart")
            metric("Комментарии", "\(comments)", "bubble.left")
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
            Text(value)
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

    private func avatar(_ raw: String?) -> some View {
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
        .frame(width: 52, height: 52)
        .clipShape(Circle())
    }
}
