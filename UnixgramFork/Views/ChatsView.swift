import SwiftUI

struct ChatsView: View {
    @State private var query = ""
    @State private var chats = Chat.mocks

    private var filtered: [Chat] {
        let sorted = chats.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            StoriesStrip()

            ForEach(filtered) { chat in
                NavigationLink(value: chat) {
                    ChatRow(chat: chat)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        togglePin(chat)
                    } label: {
                        Label(chat.isPinned ? "Unpin" : "Pin", systemImage: "pin.fill")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {} label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {} label: {
                        Label("Mute", systemImage: "speaker.slash.fill")
                    }
                    .tint(.gray)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Unixgram")
        .searchable(text: $query, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .navigationDestination(for: Chat.self) { chat in
            ChatView(chat: chat)
        }
    }

    private func togglePin(_ chat: Chat) {
        guard let i = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[i].isPinned.toggle()
    }
}

private struct StoriesStrip: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                story("Your story", symbol: "plus")
                story("Alex", symbol: "person.fill")
                story("Design", symbol: "paintbrush.fill")
                story("News", symbol: "megaphone.fill")
            }
            .padding(.vertical, 6)
        }
        .listRowSeparator(.hidden)
    }

    private func story(_ name: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 3
                    )
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 50, height: 50)
                Image(systemName: symbol)
            }
            Text(name)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 64)
        }
    }
}

private struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                Text(chat.title.prefix(1).uppercased())
                    .font(.title3.bold())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                    if chat.isMuted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(chat.updatedAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(chat.subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.blue))
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}
