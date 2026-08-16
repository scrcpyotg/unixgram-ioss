import SwiftUI

struct ChatView: View {
    let chat: Chat
    @State private var messages: [Message]
    @State private var draft = ""

    init(chat: Chat) {
        self.chat = chat
        _messages = State(initialValue: Message.mocks(chatID: chat.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .background {
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.secondarySystemBackground).opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .onChange(of: messages.count) {
                    if let id = messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            Composer(text: $draft, send: send)
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Search", systemImage: "magnifyingglass") {}
                    Button("Mute", systemImage: "speaker.slash") {}
                    Button("Clear history", systemImage: "trash", role: .destructive) {}
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        messages.append(
            .init(
                id: UUID().uuidString,
                chatID: chat.id,
                senderID: "me",
                text: text,
                createdAt: .now,
                isOutgoing: true,
                status: .sent
            )
        )
    }
}

private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 55) }

            VStack(alignment: .leading, spacing: 3) {
                Text(message.text)
                    .textSelection(.enabled)
                HStack(spacing: 3) {
                    Spacer()
                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if message.isOutgoing {
                        Image(systemName: message.status == .read ? "checkmark.circle.fill" : "checkmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(message.isOutgoing ? Color.accentColor.opacity(0.22) : Color(.secondarySystemBackground))
            )

            if !message.isOutgoing { Spacer(minLength: 55) }
        }
    }
}

private struct Composer: View {
    @Binding var text: String
    let send: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                Image(systemName: "paperclip")
            }

            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemBackground))
                )

            Button(action: text.isEmpty ? {} : send) {
                Image(systemName: text.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                    .font(.title2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
