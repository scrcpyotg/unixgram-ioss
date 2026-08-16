import SwiftUI

struct Community: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let followers: Int
    let verified: Bool
}

struct DiscoverView: View {
    @State private var search = ""

    private let communities = [
        Community(name: "unix", handle: "@unixgram", followers: 83, verified: true),
        Community(name: "Unixgram Testing", handle: "@unixtest", followers: 49, verified: true),
        Community(name: "Universal Memes", handle: "@universalmemes", followers: 17, verified: false),
        Community(name: "all-seeing", handle: "@vbiv", followers: 14, verified: false),
        Community(name: "Weterkov | news", handle: "@weterkovnews", followers: 12, verified: false),
        Community(name: "Роблокс Хаус", handle: "@rblx", followers: 10, verified: false)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Поиск в Unixgram", text: $search)
                        .font(.system(size: 19))
                }
                .padding(.horizontal, 18)
                .frame(height: 58)
                .background(UGTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color(red: 0.44, green: 0.31, blue: 0.76), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 18)

                Divider().overlay(Color.white.opacity(0.10))

                sectionHeader("Сообщества", right: "Все")

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.purple.opacity(0.14))
                        .frame(width: 72, height: 72)
                        .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.purple))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Создать канал").font(.system(size: 20, weight: .semibold))
                        Text("Публикуйте для подписчиков").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                ForEach(communities) { c in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(.gray.opacity(0.25))
                            .frame(width: 68, height: 68)
                            .overlay(Text(c.name.prefix(1)).font(.title2.bold()))

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 5) {
                                Text(c.name).font(.system(size: 20, weight: .semibold))
                                if c.verified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text("\(c.handle) · \(c.followers) подписчиков")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Канал")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(UGTheme.surface2)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }

                Divider().overlay(Color.white.opacity(0.10))
                    .padding(.top, 8)

                sectionHeader("Сейчас в трендах", right: nil)

                TrendRow(tag: "#nft", count: 303)
                Divider().overlay(Color.white.opacity(0.08))
                TrendRow(tag: "#wetertop", count: 297)
                Divider().overlay(Color.white.opacity(0.08))
                TrendRow(tag: "#akt", count: 181)
            }
            .padding(.bottom, 24)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionHeader(_ title: String, right: String?) -> some View {
        HStack {
            Text(title).font(.system(size: 22, weight: .bold))
            Spacer()
            if let right {
                Text(right).font(.system(size: 18, weight: .bold))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct TrendRow: View {
    let tag: String
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(UGTheme.surface2)
                .frame(width: 64, height: 64)
                .overlay(Image(systemName: "number").font(.title2))
            VStack(alignment: .leading, spacing: 3) {
                Text(tag).font(.system(size: 20, weight: .semibold))
                Text("\(count) постов").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}
