import SwiftUI

struct UnixgramRealConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSession: AppSession
    let conversation: UGConversationDTO

    @State private var detail: UGConversationDetailResponse?
    @State private var draft = ""
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var typingTask: Task<Void, Never>?
    @State private var pinnedMessages: [UGMessageDTO] = []
    @State private var scheduledMessages: [UGMessageDTO] = []

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(Color.white.opacity(0.08))

            if let detail {
                messages(detail)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .alert("Ошибка Unixgram", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
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

            Spacer()

            Image(systemName: "phone")
            Image(systemName: "video")
            Image(systemName: "ellipsis")
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
    }

    private var peerAccent: Color? {
        UnixgramPremiumPalette.accent(
            premium: detail?.peer?.premium,
            palette: detail?.peer?.profilePalette
        )
    }

    private var peerHeaderContent: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: detail?.peer?.avatarUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle().fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(detail?.peer?.displayName ?? detail?.peer?.username ?? "Unixgram")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(peerAccent ?? Color.white)

                    if detail?.peer?.premium == true {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(peerAccent ?? Color.purple)
                    }

                    if let gift = detail?.peer?.statusGift {
                        UnixgramStatusGiftIcon(gift: gift, size: 19)
                    }
                }

                Text(detail?.peer?.username.map { "@\($0)" } ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func messages(_ detail: UGConversationDetailResponse) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(detail.messages) { message in
                        RealMessageBubble(
                            message: message,
                            myUserID: nil
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.035, green: 0.025, blue: 0.055)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onAppear {
                if let last = detail.messages.last?.id {
                    proxy.scrollTo(last, anchor: .bottom)
                }
                Task {
                    try? await UnixgramRealAPIClient.shared.markRead(conversationId: conversation.id)
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {} label: {
                Image(systemName: "plus")
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }

            TextField("Сообщение", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onChange(of: draft) {
                    scheduleTyping()
                }

            Button {
                Task { await send() }
            } label: {
                if sending {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 40, height: 40)
                        .background(.white)
                        .clipShape(Circle())
                } else {
                    Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white : .black)
                        .frame(width: 40, height: 40)
                        .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.purple : Color.white)
                        .clipShape(Circle())
                }
            }
            .disabled(sending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func reload() async {
        do {
            async let detailTask = UnixgramRealAPIClient.shared.conversation(id: conversation.id)
            async let pinnedTask = UnixgramRealAPIClient.shared.pinnedMessages(conversationId: conversation.id)
            async let scheduledTask = UnixgramRealAPIClient.shared.scheduledMessages(conversationId: conversation.id)
            detail = try await detailTask
            pinnedMessages = (try? await pinnedTask) ?? []
            scheduledMessages = (try? await scheduledTask) ?? []
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

    private func scheduleTyping() {
        typingTask?.cancel()

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        typingTask = Task {
            do {
                try await UnixgramRealAPIClient.shared.setTyping(
                    conversationId: conversation.id,
                    typing: !text.isEmpty
                )

                try await Task.sleep(for: .seconds(2))

                if !Task.isCancelled {
                    try await UnixgramRealAPIClient.shared.setTyping(
                        conversationId: conversation.id,
                        typing: false
                    )
                }
            } catch {}
        }
    }
}

private struct RealMessageBubble: View {
    let message: UGMessageDTO
    let myUserID: String?

    private var outgoing: Bool {
        if let myUserID, let senderID = message.sender?.id {
            return senderID == myUserID
        }
        return message.sender?.username == "aeternal"
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if outgoing { Spacer(minLength: 55) }

            VStack(alignment: .leading, spacing: 5) {
                if let content = message.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 16))
                        .textSelection(.enabled)
                }

                if let reactions = message.reactions, !reactions.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(reactions.enumerated()), id: \.offset) { _, reaction in
                            HStack(spacing: 3) {
                                Text(reaction.emoji)
                                Text("\(reaction.count)")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 26)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 4) {
                    Spacer()
                    if let raw = message.createdAt {
                        Text(formatTime(raw))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(outgoing
                          ? Color(red: 0.26, green: 0.20, blue: 0.48)
                          : Color(red: 0.10, green: 0.10, blue: 0.12))
            )

            if !outgoing { Spacer(minLength: 55) }
        }
    }

    private func formatTime(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
