import SwiftUI

struct RealChatView: View {
    let conversation: UGConversation
    @State private var messages = UGMockData.messages
    @State private var draft = ""
    @State private var showingGiftPicker = false

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            Divider().overlay(Color.white.opacity(0.08))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        datePill("Сегодня")

                        ForEach(messages) { message in
                            UGMessageBubble(message: message)
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
                .onChange(of: messages.count) {
                    if let id = messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }

            composer
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingGiftPicker) {
            GiftsStarsView(mode: .picker)
                .presentationDetents([.fraction(0.78), .large])
                .presentationCornerRadius(30)
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {} label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
            }

            Circle()
                .fill(LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(Text(conversation.avatarSymbol).font(.headline.bold()))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(conversation.title)
                        .font(.system(size: 18, weight: .bold))
                    if conversation.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Text(conversation.isOnline ? "в сети" : conversation.username)
                    .font(.system(size: 13))
                    .foregroundStyle(conversation.isOnline ? Color.green : Color.secondary)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "phone")
                    .font(.system(size: 19))
            }

            Button {} label: {
                Image(systemName: "video")
                    .font(.system(size: 19))
            }

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 66)
        .background(Color.black)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Сообщение", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.leading, 4)
                    .padding(.vertical, 8)

                Button {
                    showingGiftPicker = true
                } label: {
                    Image(systemName: "gift")
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 10)
            .background(Color(red: 0.08, green: 0.08, blue: 0.095))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08)))

            Button {
                sendMessage()
            } label: {
                Image(systemName: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic.fill" : "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white : .black)
                    .frame(width: 40, height: 40)
                    .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.purple : Color.white)
                    .clipShape(Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        draft = ""
        messages.append(
            .init(
                id: UUID().uuidString,
                senderID: "me",
                date: .now,
                isOutgoing: true,
                kind: .text(value),
                isRead: false
            )
        )
    }

    private func datePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
    }
}

private struct UGMessageBubble: View {
    let message: UGChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isOutgoing { Spacer(minLength: 54) }

            VStack(alignment: .leading, spacing: 6) {
                content

                HStack(spacing: 4) {
                    Spacer()
                    Text(message.date, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if message.isOutgoing {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 10))
                            .foregroundStyle(message.isRead ? Color.cyan : Color.secondary)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.isOutgoing ? Color(red: 0.26, green: 0.20, blue: 0.48) : Color(red: 0.10, green: 0.10, blue: 0.12))
            )

            if !message.isOutgoing { Spacer(minLength: 54) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .text(let text):
            Text(text)
                .font(.system(size: 16))

        case .photo(let caption):
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 220, height: 150)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                if let caption {
                    Text(caption)
                        .font(.system(size: 15))
                }
            }

        case .voice(let duration):
            HStack(spacing: 10) {
                Circle()
                    .fill(.purple)
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "play.fill").font(.caption))
                HStack(spacing: 3) {
                    ForEach(0..<18, id: \.self) { idx in
                        Capsule()
                            .fill(Color.white.opacity(idx < 7 ? 0.8 : 0.28))
                            .frame(width: 3, height: CGFloat(8 + (idx % 5) * 4))
                    }
                }
                Text("\(Int(duration))с")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .gift(let title, let stars):
            VStack(spacing: 8) {
                Text("🧸")
                    .font(.system(size: 56))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                Label("\(stars)", systemImage: "star.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
            }
            .frame(width: 150)
        }
    }
}
