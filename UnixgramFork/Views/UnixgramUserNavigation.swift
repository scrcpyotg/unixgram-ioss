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
                UnixgramContentUnavailableView(
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
                        .foregroundStyle(
                            UnixgramPremiumPalette.accent(
                                premium: user.premium,
                                palette: user.profilePalette
                            ) ?? Color.primary
                        )

                    if let badge = user.verificationBadge, badge != "NONE" {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }

                    if user.premium == true {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(
                                UnixgramPremiumPalette.accent(
                                    premium: user.premium,
                                    palette: user.profilePalette
                                ) ?? Color.purple
                            )
                    }

                    if let gift = user.statusGift {
                        UnixgramStatusGiftIcon(gift: gift, size: 19)
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

    var body: some View {
        // There is now a single native profile implementation for both the
        // current account and every public user. Keeping this wrapper means
        // all existing navigation entry points (feed, comments, search,
        // followers, notifications and chats) automatically receive the
        // complete profile screen without having to duplicate UI or API work.
        UnixgramRealProfileView(username: username)
    }
}
