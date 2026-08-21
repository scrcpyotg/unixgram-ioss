import SwiftUI

struct UnixgramRealMessagesView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    @State private var conversations: [UGConversationDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var folders: [UGMessageFolder] = []
    @State private var selectedFolderID: String?
    @State private var searchText = ""

    var body: some View {
        Group {
            if !liveSession.isAuthenticated {
                notLoggedIn
            } else if isLoading && conversations.isEmpty {
                loadingState
            } else if filteredConversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(Color.black)
        .navigationTitle("Сообщения")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Поиск"
        )
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

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !folders.isEmpty {
                    folderStrip
                        .padding(.bottom, 8)
                }

                ForEach(filteredConversations) { conversation in
                    NavigationLink {
                        UnixgramRealConversationView(conversation: conversation)
                    } label: {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(Color.white.opacity(0.055))
                        .padding(.leading, 82)
                }
            }
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.black)
    }

    private var folderStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                folderChip(
                    title: "Все",
                    icon: "tray.full.fill",
                    selected: selectedFolderID == nil
                ) {
                    selectedFolderID = nil
                }

                ForEach(folders.sorted(by: folderSort)) { folder in
                    folderChip(
                        title: folder.name?.nilIfBlank ?? "Папка",
                        icon: folderIcon(folder.icon),
                        selected: selectedFolderID == folder.id
                    ) {
                        selectedFolderID = folder.id
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func folderChip(
        title: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                selected
                ? Color.purple.opacity(0.26)
                : Color.white.opacity(0.055)
            )
            .overlay(
                Capsule()
                    .stroke(
                        selected
                        ? Color.purple.opacity(0.52)
                        : Color.white.opacity(0.055),
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func conversationRow(_ conversation: UGConversationDTO) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: peerAvatar(conversation))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.55),
                                        Color.blue.opacity(0.40)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                Text(String(peerName(conversation).prefix(1)).uppercased())
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            peerAccent(conversation)?.opacity(0.62)
                                ?? Color.white.opacity(0.06),
                            lineWidth: 1.5
                        )
                )

                if let unread = conversation.unreadCount, unread > 0 {
                    Circle()
                        .fill(peerAccent(conversation) ?? Color.purple)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(peerName(conversation))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(peerAccent(conversation) ?? Color.white)
                        .lineLimit(1)

                    if conversation.members?.first?.verificationBadge?.uppercased() != "NONE",
                       conversation.members?.first?.verificationBadge?.isEmpty == false {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if conversation.members?.first?.premium == true {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(peerAccent(conversation) ?? Color.purple)
                    }

                    if conversation.pinned == true {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    if let date = conversation.lastMessage?.createdAt {
                        Text(shortDate(date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .center, spacing: 7) {
                    Text(lastMessagePreview(conversation))
                        .font(.system(size: 14))
                        .foregroundStyle(
                            conversation.unreadCount ?? 0 > 0
                            ? Color.white.opacity(0.78)
                            : Color.secondary
                        )
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let unread = conversation.unreadCount, unread > 0 {
                        Text(unread > 99 ? "99+" : "\(unread)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(height: 21)
                            .background(peerAccent(conversation) ?? Color.purple)
                            .clipShape(Capsule())
                    } else if conversation.markedUnread == true {
                        Circle()
                            .fill(peerAccent(conversation) ?? Color.purple)
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.purple)
            Text("Загружаем диалоги…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notLoggedIn: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.16))
                    .frame(width: 84, height: 84)
                Image(systemName: "message.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.purple)
            }

            Text("Нужен вход в Unixgram")
                .font(.system(size: 24, weight: .bold))

            Text("Авторизуйтесь через официальный веб-экран Unixgram. Пароль остаётся на странице Unixgram — приложение использует только созданную сессию.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            NavigationLink {
                UnixgramWebLoginView(presentation: .modal)
            } label: {
                Text("Войти через Unixgram")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(Color.purple)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 78, height: 78)
                Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                    .font(.system(size: 31))
                    .foregroundStyle(.secondary)
            }

            Text(searchText.isEmpty ? "Пока нет сообщений" : "Ничего не найдено")
                .font(.headline)

            if searchText.isEmpty {
                Button("Обновить") {
                    Task { await load() }
                }
                .font(.subheadline.bold())
                .foregroundStyle(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredConversations: [UGConversationDTO] {
        var items = conversations

        if let selectedFolderID {
            items = items.filter { $0.folderId == selectedFolderID }
        }

        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else { return items }

        return items.filter { conversation in
            peerName(conversation).lowercased().contains(query)
            || conversation.members?.contains(where: {
                $0.username?.lowercased().contains(query) == true
            }) == true
            || conversation.lastMessage?.content?.lowercased().contains(query) == true
        }
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
        conversation.avatarUrl
            ?? conversation.members?.first?.avatarUrl
            ?? ""
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

    private func lastMessagePreview(_ conversation: UGConversationDTO) -> String {
        if let content = conversation.lastMessage?.content?.nilIfBlank {
            let parsed = UnixgramChatContentParser.textAndInlineAttachment(content)
            if let text = parsed.text {
                return text.replacingOccurrences(of: "\n", with: " ")
            }
            if let attachment = parsed.attachment {
                switch attachment.kind {
                case .image: return "📷 Фото"
                case .video: return "🎬 Видео"
                case .file: return "📎 Файл"
                }
            }
        }

        if conversation.lastMessage?.media != nil {
            return "📎 Вложение"
        }

        return "Нет сообщений"
    }

    private func shortDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: raw) else { return "" }

        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }

        if Calendar.current.isDateInYesterday(date) {
            return "Вчера"
        }

        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func folderSort(_ lhs: UGMessageFolder, _ rhs: UGMessageFolder) -> Bool {
        (lhs.position ?? Int.max) < (rhs.position ?? Int.max)
    }

    private func folderIcon(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "work": return "briefcase.fill"
        case "friends", "people": return "person.2.fill"
        case "archive": return "archivebox.fill"
        case "star", "favorites": return "star.fill"
        default: return "folder.fill"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
