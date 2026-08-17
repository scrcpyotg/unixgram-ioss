import SwiftUI

struct FeedHomeView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("Вы пока ни на кого не подписаны.")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)

                    StoriesMiniRow()
                        .padding(.top, 8)
                }

                ComposerCard()
                    .padding(.horizontal, 14)

                FeedPostCard(
                    name: "господь 🧊",
                    handle: "@have",
                    age: "8 мин.",
                    text: "ЗА ПОДПИСКУ ДАРЮ ПЕПЕ #wetertop #nft #hao #have #akt #koma #neto #fyp #rec #инцелмаксинг #bmr",
                    stats: ("2", "2", "0", "31")
                )
                .padding(.horizontal, 14)

                PollPostCard()
                    .padding(.horizontal, 14)

                SuggestedPeopleStrip()
                    .padding(.horizontal, 14)

                GiftPostCard()
                    .padding(.horizontal, 14)

                ImagePostCard()
                    .padding(.horizontal, 14)
            }
            .padding(.bottom, 22)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct StoriesMiniRow: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .stroke(
                        LinearGradient(colors: [.green, .cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 4
                    )
                    .frame(width: 78, height: 78)
                Circle()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 68, height: 68)
                    .overlay(Image(systemName: "scribble.variable").font(.title2))
                Circle()
                    .fill(.purple)
                    .frame(width: 24, height: 24)
                    .overlay(Image(systemName: "plus").font(.caption.bold()))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("No active stories yet.")
                    .foregroundStyle(.secondary)
                Text("My story")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

private struct ComposerCard: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "scribble.variable"))
                Text("Что нового?")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 24) {
                ForEach(["photo.badge.plus", "film", "music.note", "face.smiling", "chart.bar", "ellipsis"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "paperplane.fill").foregroundStyle(.black))
            }
        }
        .padding(18)
        .background(UGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct FeedPostCard: View {
    let name: String
    let handle: String
    let age: String
    let text: String
    let stats: (String, String, String, String)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle().fill(.gray.opacity(0.35)).frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(name).bold()
                        Text(handle).foregroundStyle(.secondary)
                        Text("· \(age)").foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }

            Text(text)
                .font(.system(size: 19))
                .foregroundStyle(.white)

            Text("文A Перевести")
                .foregroundStyle(Color(red: 0.65, green: 0.52, blue: 1.0))
                .font(.system(size: 17, weight: .semibold))

            HStack(spacing: 22) {
                Label(stats.0, systemImage: "heart")
                Label(stats.1, systemImage: "bubble.left")
                Label(stats.2, systemImage: "arrow.2.squarepath")
                Spacer()
                Image(systemName: "star.fill").foregroundStyle(.orange)
                Label(stats.3, systemImage: "eye")
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 17))
        }
        .padding(18)
        .background(UGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PollPostCard: View {
    let options = ["яблоко", "единая россия", "пал палыч", "ЗЕЛЕБОБА"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle().fill(.pink.opacity(0.25)).frame(width: 54, height: 54)
                VStack(alignment: .leading) {
                    Text("@prigozhin · 6 мин.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
            Text("за кого вы будете голосовать")
                .font(.system(size: 19))
            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Text(option)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(Color.black.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.10))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(18)
        .background(UGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
