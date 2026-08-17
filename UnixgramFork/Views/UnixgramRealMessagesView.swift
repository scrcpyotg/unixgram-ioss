import SwiftUI

struct UnixgramRealMessagesView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var conversations: [UGConversationDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var folders: [UGMessageFolder] = []

    var body: some View {
        Group {
            if !liveSession.isAuthenticated {
                notLoggedIn
            } else if isLoading && conversations.isEmpty {
                ProgressView("Загружаем диалоги…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.black)
        .navigationTitle("Сообщения")
        .task {
            if !liveSession.isAuthenticated {
                await liveSession.refreshAuthentication()
            }
            if liveSession.isAuthenticated {
                await load()
            }
        }
        .refreshable {
            await load()
        }
        .alert("Ошибка Unixgram", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var list: some View {
        List(conversations) { conversation in
            NavigationLink {
                UnixgramRealConversationView(conversation: conversation)
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: peerAvatar(conversation))) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay {
                                    Text(String(peerName(conversation).prefix(1)).uppercased())
                                        .font(.headline.bold())
                                }
                        }
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(peerName(conversation))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(peerAccent(conversation) ?? Color.primary)
                                .lineLimit(1)

                            if let gift = conversation.members?.first?.statusGift {
                                UnixgramStatusGiftIcon(gift: gift, size: 18)
                            }

                            Spacer()

                            if let date = conversation.lastMessage?.createdAt {
                                Text(shortDate(date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text(conversation.lastMessage?.content ?? "Нет сообщений")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer()

                            if let unread = conversation.unreadCount, unread > 0 {
                                Text("\(unread)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .frame(height: 22)
                                    .background(peerAccent(conversation) ?? Color.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.black)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var notLoggedIn: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 54))
                .foregroundStyle(.purple)

            Text("Нужен вход в Unixgram")
                .font(.system(size: 24, weight: .bold))

            Text("Авторизуйтесь через официальный веб-экран Unixgram. Пароль остаётся на странице Unixgram — приложение забирает только созданную сессию.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            NavigationLink {
                UnixgramWebLoginView(presentation: .modal)
            } label: {
                Text("Войти через Unixgram")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 26)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Пока нет сообщений")
                .font(.headline)
            Button("Обновить") {
                Task { await load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let conversationsTask = UnixgramRealAPIClient.shared.conversations()
            async let foldersTask = UnixgramRealAPIClient.shared.messageFolders()
            conversations = try await conversationsTask
            folders = (try? await foldersTask) ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func peerName(_ conversation: UGConversationDTO) -> String {
        if let title = conversation.title, !title.isEmpty { return title }
        return conversation.members?.first?.displayName
            ?? conversation.members?.first?.username
            ?? "Unixgram"
    }

    private func peerAvatar(_ conversation: UGConversationDTO) -> String {
        conversation.avatarUrl ?? conversation.members?.first?.avatarUrl ?? ""
    }

    private func peerAccent(_ conversation: UGConversationDTO) -> Color? {
        guard conversation.title?.isEmpty != false,
              let peer = conversation.members?.first
        else { return nil }

        return UnixgramPremiumPalette.accent(
            premium: peer.premium,
            palette: peer.profilePalette
        )
    }

    private func shortDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: raw) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
