import Foundation
import SwiftUI

struct UnixgramMentionText: View {
    let text: String
    var font: Font = .body
    var color: Color = .primary
    var lineLimit: Int? = nil

    @State private var selectedUser: UnixgramMentionRoute?

    var body: some View {
        Text(attributedText)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "unixgram",
                      url.host == "user"
                else { return .systemAction }

                let value = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !value.isEmpty else { return .discarded }

                selectedUser = UnixgramMentionRoute(username: value)
                return .handled
            })
            .sheet(item: $selectedUser) { route in
                NavigationStack {
                    UnixgramPublicProfileView(username: route.username)
                }
                .preferredColorScheme(.dark)
            }
    }

    private var attributedText: AttributedString {
        let pattern = #"@[A-Za-z0-9_]{2,32}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return AttributedString(text)
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else { return AttributedString(text) }

        var result = AttributedString()
        var cursor = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }

            if cursor < range.lowerBound {
                result += AttributedString(String(text[cursor..<range.lowerBound]))
            }

            let rawMention = String(text[range])
            let username = String(rawMention.dropFirst())
            var mention = AttributedString(rawMention)
            mention.foregroundColor = .blue
            mention.link = URL(string: "unixgram://user/\(username)")
            result += mention
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            result += AttributedString(String(text[cursor..<text.endIndex]))
        }

        return result
    }
}

private struct UnixgramMentionRoute: Identifiable {
    let username: String
    var id: String { username.lowercased() }
}

enum UnixgramConnectionsKind: String, CaseIterable, Identifiable {
    case followers
    case following

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followers: return "Подписчики"
        case .following: return "Подписки"
        }
    }
}

struct UnixgramConnectionsView: View {
    let username: String
    let kind: UnixgramConnectionsKind

    @State private var users: [UGUserMini] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && users.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if users.isEmpty {
                ContentUnavailableView(
                    kind == .followers ? "Подписчиков пока нет" : "Подписок пока нет",
                    systemImage: kind == .followers ? "person.2" : "person.crop.circle.badge.checkmark"
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(users) { user in
                    if let handle = user.username, !handle.isEmpty {
                        NavigationLink {
                            UnixgramPublicProfileView(username: handle)
                        } label: {
                            userRow(user)
                        }
                        .listRowBackground(Color.black)
                    } else {
                        userRow(user)
                            .listRowBackground(Color.black)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .alert("Ошибка Unixgram", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func userRow(_ user: UGUserMini) -> some View {
        HStack(spacing: 12) {
            userAvatar(user.avatarUrl, name: user.displayName ?? user.username ?? "U")
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(user.displayName ?? user.username ?? "Unixgram")
                        .font(.system(size: 16, weight: .semibold))

                    if let badge = user.verificationBadge, badge != "NONE" {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }

                    if user.premium == true {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }

                if let handle = user.username, !handle.isEmpty {
                    Text("@\(handle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            switch kind {
            case .followers:
                users = try await UnixgramRealAPIClient.shared.profileFollowers(username: username)
            case .following:
                users = try await UnixgramRealAPIClient.shared.profileFollowing(username: username)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func userAvatar(_ raw: String?, name: String) -> some View {
        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderAvatar(name)
                }
            }
            .clipShape(Circle())
        } else {
            placeholderAvatar(name)
        }
    }

    private func placeholderAvatar(_ name: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Text(String(name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
    }
}

struct UnixgramPublicProfileView: View {
    let username: String

    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @StateObject private var content = UnixgramProfileContentStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader

                if content.isLoadingTab && content.posts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 52)
                } else if content.posts.isEmpty {
                    ContentUnavailableView("Постов пока нет", systemImage: "rectangle.stack")
                        .padding(.vertical, 42)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(content.posts.enumerated()), id: \.element.id) { index, post in
                            UnixgramPublicProfilePostCard(post: post)
                                .onAppear {
                                    guard index >= content.posts.count - 3 else { return }
                                    Task { await content.loadMore(tab: .posts, username: username) }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("@\(username)")
        .task {
            await content.refresh(username: username, selectedTab: .posts)
        }
        .refreshable {
            await content.refresh(username: username, selectedTab: .posts)
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

    @ViewBuilder
    private var profileHeader: some View {
        if let profile = content.profile {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    profileCover(profile.coverUrl)
                        .frame(height: 205)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.72)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    profileAvatar(profile.avatarUrl, name: profile.displayName ?? profile.username)
                        .frame(width: 98, height: 98)
                        .overlay(Circle().stroke(Color.black, lineWidth: 4))
                        .offset(y: 45)
                        .padding(.leading, 18)
                }
                .padding(.bottom, 51)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text(profile.displayName ?? profile.username)
                            .font(.system(size: 26, weight: .bold))

                        if let badge = profile.verificationBadge, badge != "NONE" {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.cyan)
                        }

                        if profile.premium == true {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                        }
                    }

                    Text("@\(profile.username)")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)

                    if let bio = profile.bio, !bio.isEmpty {
                        UnixgramMentionText(text: bio, font: .system(size: 16), color: .white)
                    }

                    HStack(spacing: 22) {
                        NavigationLink {
                            UnixgramConnectionsView(username: profile.username, kind: .following)
                        } label: {
                            connectionStat(profile.followingCount, title: "Подписки")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            UnixgramConnectionsView(username: profile.username, kind: .followers)
                        } label: {
                            connectionStat(profile.followersCount, title: "Подписчики")
                        }
                        .buttonStyle(.plain)
                    }

                    if let music = profile.profileMusic {
                        ProfilePublicMusicStrip(music: music)
                            .padding(.top, 3)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        } else if content.isLoadingHeader {
            ProgressView("Загружаем профиль…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 70)
        }
    }

    private func connectionStat(_ value: Int?, title: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value ?? 0)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func profileCover(_ raw: String?) -> some View {
        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Rectangle().fill(Color.white.opacity(0.04))
                }
            }
        } else {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.22), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func profileAvatar(_ raw: String?, name: String) -> some View {
        if let raw, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Circle().fill(Color.white.opacity(0.08))
                }
            }
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(Text(String(name.prefix(1)).uppercased()).font(.title2.bold()))
        }
    }
}

private struct ProfilePublicMusicStrip: View {
    let music: UGProfileMusic

    var body: some View {
        UnixgramMusicRow(track: UnixgramMusicTrack(music))
    }
}

private struct UnixgramPublicProfilePostCard: View {
    let post: UGHARFeedPost
    @State private var selectedMedia: UnixgramMediaViewerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                postAvatar
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.displayName ?? post.author?.username ?? "Unixgram")
                        .font(.system(size: 15, weight: .bold))
                    if let handle = post.author?.username {
                        Text("@\(handle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let content = post.content, !content.isEmpty {
                UnixgramMentionText(text: content, font: .system(size: 16), color: .white)
            }

            postMedia

            if let music = post.music {
                UnixgramMusicRow(track: UnixgramMusicTrack(music))
            }

            UnixgramPostInteractionBar(post: post, showViews: true, showBookmark: true)
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
    private var postAvatar: some View {
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
                spacing: 5
            ) {
                ForEach(Array(images.prefix(4).enumerated()), id: \.offset) { _, raw in
                    AsyncImage(url: URL(string: raw)) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Rectangle().fill(Color.white.opacity(0.05)).overlay(ProgressView())
                        }
                    }
                    .frame(height: images.count == 1 ? 290 : 160)
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
                .frame(height: 250)
                .overlay(Image(systemName: "play.circle.fill").font(.system(size: 48)))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedMedia = UnixgramMediaViewerItem(url: url, kind: .video)
                }
        }
    }
}

// File-local copy used by public-profile post cards.
// The same helper in other view files is `private`, so it is not visible here.
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

            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }

        return result
    }
}
