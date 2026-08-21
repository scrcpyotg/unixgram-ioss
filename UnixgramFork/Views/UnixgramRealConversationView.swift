import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UnixgramRealConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    let conversation: UGConversationDTO

    @State private var detail: UGConversationDetailResponse?
    @State private var draft = ""
    @State private var sending = false
    @State private var uploading = false
    @State private var uploadProgressLabel: String?
    @State private var errorMessage: String?
    @State private var typingTask: Task<Void, Never>?
    @State private var pinnedMessages: [UGMessageDTO] = []
    @State private var scheduledMessages: [UGMessageDTO] = []
    @State private var peerPresence: UGPresenceDTO?

    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showChatMenu = false
    @State private var showAttachmentMenu = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if showSearch {
                searchBar
            }

            if let pinned = pinnedMessages.first {
                pinnedBanner(pinned)
            }

            ZStack {
                UnixgramChatWallpaper()

                if let detail {
                    messages(detail)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            composer
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                appSession.isConversationOpen = true
            }
        }
        .task {
            await reload()
        }
        .onDisappear {
            withAnimation(.easeIn(duration: 0.16)) {
                appSession.isConversationOpen = false
            }
            typingTask?.cancel()
            Task {
                try? await UnixgramRealAPIClient.shared.setTyping(
                    conversationId: conversation.id,
                    typing: false
                )
            }
        }
        .confirmationDialog(
            "Вложения",
            isPresented: $showAttachmentMenu,
            titleVisibility: .visible
        ) {
            Button("Фото или изображение") {
                showPhotoPicker = true
            }
            Button("Файл") {
                showFileImporter = true
            }
            Button("Отмена", role: .cancel) {}
        }
        .confirmationDialog(
            "Чат",
            isPresented: $showChatMenu,
            titleVisibility: .visible
        ) {
            if !pinnedMessages.isEmpty {
                Button("Закреплённые: \(pinnedMessages.count)") {}
            }
            if !scheduledMessages.isEmpty {
                Button("Отложенные: \(scheduledMessages.count)") {}
            }
            Button("Обновить") {
                Task { await reload() }
            }
            Button("Отмена", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task { await uploadPhoto(item) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await uploadFile(url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.075))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            if let username = detail?.peer?.username, !username.isEmpty {
                NavigationLink {
                    UnixgramPublicProfileView(username: username)
                } label: {
                    peerHeaderContent
                }
                .buttonStyle(.plain)
            } else {
                peerHeaderContent
            }

            Spacer(minLength: 6)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showSearch.toggle()
                    if !showSearch { searchText = "" }
                }
            } label: {
                Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.065))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                showChatMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.065))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.055, blue: 0.070),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
        }
    }

    private var peerHeaderContent: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: detail?.peer?.avatarUrl ?? peerAvatarFallback)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay {
                                Text(String(peerDisplayName.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(peerAccent?.opacity(0.70) ?? Color.white.opacity(0.09), lineWidth: 1.5)
                )

                if peerPresence?.online == true {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(peerDisplayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(peerAccent ?? Color.white)
                        .lineLimit(1)

                    if detail?.peer?.verificationBadge?.uppercased() != "NONE",
                       detail?.peer?.verificationBadge?.isEmpty == false {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if detail?.peer?.premium == true {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(peerAccent ?? Color.purple)
                    }
                }

                Text(peerSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(peerPresence?.online == true ? Color.green : Color.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Поиск в чате", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 42)
        .background(Color.white.opacity(0.055))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
        }
    }

    // MARK: - Messages

    private func messages(_ detail: UGConversationDetailResponse) -> some View {
        let visible = filteredMessages(detail.messages)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, message in
                        if shouldShowDateSeparator(message, previous: previousMessage(at: index, in: visible)) {
                            dateSeparator(message.createdAt)
                                .padding(.vertical, 8)
                        }

                        RealMessageBubble(
                            message: message,
                            myUserID: liveSession.currentUser?.id,
                            myUsername: liveSession.currentUser?.username,
                            peerAvatarURL: detail.peer?.avatarUrl,
                            compactWithPrevious: shouldGroup(
                                previousMessage(at: index, in: visible),
                                message
                            ),
                            compactWithNext: shouldGroup(
                                message,
                                nextMessage(at: index, in: visible)
                            )
                        )
                        .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("CHAT_BOTTOM")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom)
                }

                Task {
                    try? await UnixgramRealAPIClient.shared.markRead(
                        conversationId: conversation.id
                    )
                }
            }
            .onChange(of: detail.messages.count) { _ in
                guard searchText.isEmpty else { return }
                withAnimation(.easeOut(duration: 0.20)) {
                    proxy.scrollTo("CHAT_BOTTOM", anchor: .bottom)
                }
            }
        }
    }

    private func pinnedBanner(_ message: UGMessageDTO) -> some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(peerAccent ?? Color.purple)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Закреплённое сообщение")
                    .font(.caption.bold())
                    .foregroundStyle(peerAccent ?? Color.purple)

                Text(message.content?.nilIfBlank ?? "Вложение")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer()

            if pinnedMessages.count > 1 {
                Text("\(pinnedMessages.count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 50)
        .background(Color.black.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)
        }
    }

    private func dateSeparator(_ raw: String?) -> some View {
        Text(formattedDay(raw))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Color.black.opacity(0.38))
            .clipShape(Capsule())
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            if uploading, let label = uploadProgressLabel {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.purple)
                        .scaleEffect(0.80)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    showAttachmentMenu = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(uploading ? 0.35 : 0.82))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.055))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(uploading || sending)

                HStack(alignment: .bottom, spacing: 8) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 9)

                    TextField("Сообщение", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.vertical, 9)
                        .onChange(of: draft) { _ in
                            scheduleTyping()
                        }
                }
                .padding(.horizontal, 11)
                .background(Color.white.opacity(0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task { await send() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.purple.opacity(0.88)
                                : (peerAccent ?? Color.purple)
                            )

                        if sending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? "mic.fill"
                                  : "arrow.up")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(sending || uploading || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.86 : 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
        }
    }

    // MARK: - Data

    private func reload() async {
        do {
            async let detailTask = UnixgramRealAPIClient.shared.conversation(id: conversation.id)
            async let pinnedTask = UnixgramRealAPIClient.shared.pinnedMessages(conversationId: conversation.id)
            async let scheduledTask = UnixgramRealAPIClient.shared.scheduledMessages(conversationId: conversation.id)

            let loadedDetail = try await detailTask
            detail = loadedDetail
            pinnedMessages = (try? await pinnedTask) ?? []
            scheduledMessages = (try? await scheduledTask) ?? []

            if let peerID = loadedDetail.peer?.id, !peerID.isEmpty {
                if let presenceMap = try? await UnixgramRealAPIClient.shared.presence(ids: [peerID]) {
                    peerPresence = presenceMap[peerID]
                }
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        sending = true
        defer { sending = false }

        do {
            _ = try await UnixgramRealAPIClient.shared.sendMessage(
                conversationId: conversation.id,
                content: text
            )
            draft = ""
            try? await UnixgramRealAPIClient.shared.setTyping(
                conversationId: conversation.id,
                typing: false
            )
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        uploading = true
        uploadProgressLabel = "Загружаем фото…"
        defer {
            uploading = false
            uploadProgressLabel = nil
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  !data.isEmpty
            else {
                throw UnixgramChatAttachmentError.couldNotReadFile
            }

            let mime = item.supportedContentTypes
                .first?
                .preferredMIMEType ?? "image/jpeg"
            let ext = item.supportedContentTypes
                .first?
                .preferredFilenameExtension ?? "jpg"

            let upload = try await UnixgramRealAPIClient.shared.uploadChatAttachment(
                data: data,
                filename: "image-\(Int(Date().timeIntervalSince1970)).\(ext)",
                mimeType: mime,
                kind: .image,
                conversationId: conversation.id
            )

            try await sendUploadedAttachmentURL(upload.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadFile(_ url: URL) async {
        uploading = true
        uploadProgressLabel = "Загружаем файл…"
        defer {
            uploading = false
            uploadProgressLabel = nil
        }

        do {
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let values = try? url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentTypeKey
            ])

            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard !data.isEmpty else {
                throw UnixgramChatAttachmentError.couldNotReadFile
            }

            let type = values?.contentType
                ?? UTType(filenameExtension: url.pathExtension)
            let mime = type?.preferredMIMEType ?? "application/octet-stream"

            let upload = try await UnixgramRealAPIClient.shared.uploadChatAttachment(
                data: data,
                filename: url.lastPathComponent.nilIfBlank ?? "file",
                mimeType: mime,
                kind: .file,
                conversationId: conversation.id
            )

            try await sendUploadedAttachmentURL(upload.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendUploadedAttachmentURL(_ url: String) async throws {
        let caption = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = caption.isEmpty ? url : "\(caption)\n\(url)"

        _ = try await UnixgramRealAPIClient.shared.sendMessage(
            conversationId: conversation.id,
            content: content
        )

        draft = ""
        try? await UnixgramRealAPIClient.shared.setTyping(
            conversationId: conversation.id,
            typing: false
        )
        await reload()
    }

    private func scheduleTyping() {
        typingTask?.cancel()

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        typingTask = Task {
            do {
                try await UnixgramRealAPIClient.shared.setTyping(
                    conversationId: conversation.id,
                    typing: !text.isEmpty
                )

                try await Task.sleep(nanoseconds: 2_000_000_000)

                if !Task.isCancelled {
                    try await UnixgramRealAPIClient.shared.setTyping(
                        conversationId: conversation.id,
                        typing: false
                    )
                }
            } catch {}
        }
    }

    // MARK: - Presentation helpers

    private var peerAccent: Color? {
        UnixgramPremiumPalette.accent(
            premium: detail?.peer?.premium,
            palette: detail?.peer?.profilePalette
        )
    }

    private var peerDisplayName: String {
        detail?.peer?.displayName
            ?? detail?.peer?.username
            ?? conversation.title
            ?? conversation.members?.first?.displayName
            ?? conversation.members?.first?.username
            ?? "Unixgram"
    }

    private var peerAvatarFallback: String {
        conversation.avatarUrl
            ?? conversation.members?.first?.avatarUrl
            ?? ""
    }

    private var peerSubtitle: String {
        if detail?.peer?.isService == true {
            return "служебные уведомления"
        }

        if peerPresence?.online == true {
            return "в сети"
        }

        if let raw = peerPresence?.lastSeenAt,
           let date = ISO8601DateFormatter().date(from: raw) {
            return "был(а) \(date.formatted(date: .omitted, time: .shortened))"
        }

        if let username = detail?.peer?.username, !username.isEmpty {
            return "@\(username)"
        }

        if let count = conversation.memberCount, count > 1 {
            return "\(count) участников"
        }

        return "Unixgram"
    }

    private func filteredMessages(_ messages: [UGMessageDTO]) -> [UGMessageDTO] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else { return messages }

        return messages.filter { message in
            if message.content?.lowercased().contains(query) == true {
                return true
            }
            if message.sender?.displayName?.lowercased().contains(query) == true {
                return true
            }
            if message.sender?.username?.lowercased().contains(query) == true {
                return true
            }
            return false
        }
    }

    private func previousMessage(
        at index: Int,
        in messages: [UGMessageDTO]
    ) -> UGMessageDTO? {
        guard index > 0 else { return nil }
        return messages[index - 1]
    }

    private func nextMessage(
        at index: Int,
        in messages: [UGMessageDTO]
    ) -> UGMessageDTO? {
        guard index + 1 < messages.count else { return nil }
        return messages[index + 1]
    }

    private func shouldGroup(
        _ first: UGMessageDTO?,
        _ second: UGMessageDTO?
    ) -> Bool {
        guard let first, let second,
              first.sender?.id == second.sender?.id,
              let a = parsedDate(first.createdAt),
              let b = parsedDate(second.createdAt)
        else { return false }

        return abs(b.timeIntervalSince(a)) < 5 * 60
    }

    private func shouldShowDateSeparator(
        _ message: UGMessageDTO,
        previous: UGMessageDTO?
    ) -> Bool {
        guard let currentDate = parsedDate(message.createdAt) else {
            return previous == nil
        }

        guard let previous,
              let previousDate = parsedDate(previous.createdAt)
        else { return true }

        return !Calendar.current.isDate(currentDate, inSameDayAs: previousDate)
    }

    private func parsedDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func formattedDay(_ raw: String?) -> String {
        guard let date = parsedDate(raw) else { return "Сообщения" }

        if Calendar.current.isDateInToday(date) {
            return "Сегодня"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Вчера"
        }

        return date.formatted(
            .dateTime
                .day()
                .month(.wide)
        )
    }
}

private struct RealMessageBubble: View {
    let message: UGMessageDTO
    let myUserID: String?
    let myUsername: String?
    let peerAvatarURL: String?
    let compactWithPrevious: Bool
    let compactWithNext: Bool

    private var outgoing: Bool {
        if let myUserID,
           let senderID = message.sender?.id,
           !myUserID.isEmpty {
            return senderID == myUserID
        }

        if let myUsername,
           let senderUsername = message.sender?.username {
            return senderUsername.caseInsensitiveCompare(myUsername) == .orderedSame
        }

        return false
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if outgoing {
                Spacer(minLength: 48)
            } else {
                incomingAvatar
            }

            VStack(alignment: outgoing ? .trailing : .leading, spacing: 3) {
                if !outgoing,
                   !compactWithPrevious,
                   let sender = message.sender?.displayName ?? message.sender?.username,
                   !sender.isEmpty {
                    Text(sender)
                        .font(.caption.bold())
                        .foregroundStyle(
                            UnixgramPremiumPalette.accent(
                                premium: message.sender?.premium,
                                palette: message.sender?.profilePalette
                            ) ?? Color.purple.opacity(0.90)
                        )
                        .padding(.horizontal, 7)
                }

                VStack(alignment: .leading, spacing: 6) {
                    UnixgramChatRichMessageContent(
                        message: message,
                        outgoing: outgoing
                    )

                    if let reactions = message.reactions, !reactions.isEmpty {
                        reactionRow(reactions)
                    }

                    messageFooter
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background {
                    bubbleBackground
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            outgoing
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.065),
                            lineWidth: 0.8
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            if !outgoing {
                Spacer(minLength: 48)
            }
        }
        .padding(.top, compactWithPrevious ? 0 : 5)
    }

    @ViewBuilder
    private var incomingAvatar: some View {
        if compactWithNext {
            Color.clear
                .frame(width: 28, height: 28)
        } else {
            AsyncImage(url: URL(string: message.sender?.avatarUrl ?? peerAvatarURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            Text(String((message.sender?.displayName
                                         ?? message.sender?.username
                                         ?? "?").prefix(1)).uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.78))
                        }
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if outgoing {
            LinearGradient(
                colors: [
                    Color(red: 0.39, green: 0.24, blue: 0.78),
                    Color(red: 0.29, green: 0.16, blue: 0.61)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(red: 0.085, green: 0.085, blue: 0.105).opacity(0.95)
        }
    }

    private func reactionRow(_ reactions: [UGReactionDTO]) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(reactions.enumerated()), id: \.offset) { _, reaction in
                HStack(spacing: 4) {
                    Text(reaction.emoji)
                    Text("\(reaction.count)")
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 7)
                .frame(height: 25)
                .background(
                    reaction.reactedByViewer == true
                    ? Color.purple.opacity(0.30)
                    : Color.white.opacity(0.09)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            reaction.reactedByViewer == true
                            ? Color.purple.opacity(0.55)
                            : Color.clear,
                            lineWidth: 1
                        )
                )
                .clipShape(Capsule())
            }
        }
    }

    private var messageFooter: some View {
        HStack(spacing: 4) {
            if message.pinned == true {
                Image(systemName: "pin.fill")
            }

            if message.editedAt != nil {
                Text("изм.")
            }

            if let raw = message.createdAt {
                Text(formatTime(raw))
            }

            if outgoing {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.48))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func formatTime(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private enum UnixgramChatAttachmentError: LocalizedError {
    case couldNotReadFile

    var errorDescription: String? {
        switch self {
        case .couldNotReadFile:
            return "Не удалось прочитать вложение."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
