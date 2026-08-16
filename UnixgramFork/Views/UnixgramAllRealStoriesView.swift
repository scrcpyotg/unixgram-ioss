import SwiftUI

struct UnixgramAllRealStoriesView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Stories")
                    .font(.system(size: 32, weight: .bold))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(uniqueAuthors.prefix(12)) { author in
                            VStack(spacing: 7) {
                                avatar(author.avatarUrl)
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
                    .padding(.vertical, 4)
                }

                Text("Story viewer")
                    .font(.system(size: 22, weight: .bold))

                VStack(spacing: 14) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 52))
                        .foregroundStyle(.purple)

                    Text("Endpoint просмотра Stories подключён:")
                        .font(.headline)

                    Text("POST /api/social/stories/{storyId}/view")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("Но текущий HAR не содержит endpoint списка Stories. Поэтому я не подставляю авторов ленты как фиктивные реальные Stories — список появится, когда поймаем GET Stories из web.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .padding(18)
        }
        .background(Color.black)
        .task {
            if store.feed.isEmpty {
                await store.refreshAll()
            }
        }
    }

    private var uniqueAuthors: [UGHARFeedAuthor] {
        var seen = Set<String>()
        return store.feed.compactMap(\.author).filter { seen.insert($0.id).inserted }
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
        .frame(width: 68, height: 68)
        .clipShape(Circle())
    }
}
