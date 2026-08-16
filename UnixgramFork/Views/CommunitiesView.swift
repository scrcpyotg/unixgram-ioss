import SwiftUI

struct CommunityItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let handle: String
    let followers: Int
    let verified: Bool
    let subscribed: Bool
}

struct CommunitiesView: View {
    @State private var selectedTab = 0
    @State private var showCreate = false
    @State private var query = ""

    private let mine: [CommunityItem] = [
        .init(name: "aeternal", handle: "@menace", followers: 1, verified: false, subscribed: true),
        .init(name: "Unixgram Testing", handle: "@unixtest", followers: 49, verified: true, subscribed: true)
    ]

    private let browse: [CommunityItem] = [
        .init(name: "unix", handle: "@unixgram", followers: 85, verified: true, subscribed: false),
        .init(name: "Unixgram Testing", handle: "@unixtest", followers: 49, verified: true, subscribed: true),
        .init(name: "Unixgram Owners", handle: "@nya", followers: 18, verified: false, subscribed: false),
        .init(name: "Universal Memes", handle: "@universalmemes", followers: 17, verified: false, subscribed: false),
        .init(name: "all-seeing", handle: "@vbiv", followers: 14, verified: false, subscribed: false),
        .init(name: "Weterkov | news", handle: "@weterkovnews", followers: 12, verified: false, subscribed: false),
        .init(name: "Роблокс Хаус", handle: "@rblx", followers: 10, verified: false, subscribed: false),
        .init(name: "Центр Ахуя Сиквел", handle: "@cas", followers: 8, verified: false, subscribed: false),
        .init(name: "DarkWergut", handle: "@darkwergut", followers: 7, verified: false, subscribed: false)
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Сообщества")
                        .font(.system(size: 31, weight: .bold))
                    Spacer()
                    Button {
                        showCreate = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Создать")
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                HStack {
                    tabButton("Мои", 0)
                    tabButton("Обзор", 1)
                }
                .padding(.top, 20)

                Divider().overlay(Color.white.opacity(0.10))

                if selectedTab == 1 {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Поиск каналов", text: $query)
                            .font(.system(size: 19))
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(UGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                CommunityRow(item: item)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.leading, 20)
                        }
                    }
                }
            }
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CommunityItem.self) { item in
                ChannelDetailView(channel: item)
            }

            if showCreate {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .background(.ultraThinMaterial)
                    .onTapGesture { showCreate = false }

                CreateChannelSheet(isPresented: $showCreate)
                    .padding(.horizontal, 28)
            }
        }
    }

    private var filteredItems: [CommunityItem] {
        let items = selectedTab == 0 ? mine : browse
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.handle.localizedCaseInsensitiveContains(query)
        }
    }

    private func tabButton(_ title: String, _ index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(selectedTab == index ? .white : .secondary)
                Rectangle()
                    .fill(selectedTab == index ? UGTheme.blue : .clear)
                    .frame(height: 4)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CommunityRow: View {
    let item: CommunityItem

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
                .overlay {
                    Text(item.name.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    if item.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                    }
                }
                Text("\(item.handle) · \(item.followers) подписчиков")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.subscribed {
                Text("Вы подписаны")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(UGTheme.surface2)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}

private struct CreateChannelSheet: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var link = ""
    @State private var description = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .foregroundStyle(.cyan)
                    Text("Новый канал")
                        .font(.system(size: 24, weight: .bold))
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }

            fieldLabel("НАЗВАНИЕ")
            field("Например: Unixgram News", text: $name)

            fieldLabel("ПУБЛИЧНАЯ ССЫЛКА")
            field("@ unixnews", text: $link)
            Text("3–32 символа: латиница, цифры и _")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            fieldLabel("ОПИСАНИЕ")
            TextField("О чём ваш канал?", text: $description, axis: .vertical)
                .lineLimit(4...7)
                .padding(16)
                .background(UGTheme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10)))

            Button {} label: {
                Text("Создать канал")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(Color.white.opacity(0.58))
                    .clipShape(Capsule())
            }
            .padding(.top, 10)
        }
        .padding(24)
        .background(Color(red: 0.035, green: 0.035, blue: 0.045))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.16)))
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(1)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(UGTheme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10)))
    }
}
