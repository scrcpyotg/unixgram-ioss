import SwiftUI

struct GiftPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle().fill(.gray.opacity(0.3)).frame(width: 54, height: 54)
                Text("японец").font(.system(size: 19, weight: .bold))
                Text("@frea · 8 мин.").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }

            Text("Уже подарил нового мишку рандому, подписывайтесь и оставляйте юзы")
                .font(.system(size: 18))

            VStack(spacing: 12) {
                Text("Вы отправили подарок за 50 звёзд")
                    .font(.system(size: 15))

                Text("🧸")
                    .font(.system(size: 92))

                Text("Подарок для КАРПИК")
                    .font(.system(size: 20, weight: .bold))

                Text("КАРПИК может добавить этот подарок в профиль или обменять на 43 звезды.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)

                Button("Посмотреть") {}
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.14)))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            PostStatsView(comments: 1, views: 17)
        }
        .padding(18)
        .background(UGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct ImagePostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle().fill(.brown.opacity(0.4)).frame(width: 54, height: 54)
                Text("rize").font(.system(size: 19, weight: .bold))
                Text("@quin · 6 мин.").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }

            Text("дайте 253в с*ка")
                .font(.system(size: 18))

            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(colors: [.gray.opacity(0.5), .brown.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                )
                .frame(height: 360)
                .overlay {
                    Text("нищий ждет пока ему\nзакинут звезды")
                        .font(.system(size: 28, weight: .black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                }

            PostStatsView(comments: 0, views: 10)
        }
        .padding(18)
        .background(UGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct SuggestedPeopleStrip: View {
    private let names = ["Darknet", "user", "marlboro"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ВОЗМОЖНО ЗНАКОМЫЕ ЛЮДИ")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Показать все")
                    .font(.system(size: 18))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(names, id: \.self) { name in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Spacer()
                                Image(systemName: "xmark")
                                    .foregroundStyle(.secondary)
                            }

                            Circle()
                                .fill(.gray.opacity(0.35))
                                .frame(width: 76, height: 76)

                            Text(name)
                                .font(.system(size: 18, weight: .bold))
                            Text("@\(name.lowercased())")
                                .foregroundStyle(.secondary)
                            Text("Популярный профи…")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Подписаться") {}
                                .foregroundStyle(.black)
                                .fontWeight(.bold)
                                .padding(.horizontal, 16)
                                .frame(height: 42)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                        .padding(14)
                        .frame(width: 190, height: 255)
                        .background(UGTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
        }
    }
}

private struct PostStatsView: View {
    let comments: Int
    let views: Int

    var body: some View {
        HStack(spacing: 20) {
            Label("0", systemImage: "heart")
            Label("\(comments)", systemImage: "bubble.left")
            Label("0", systemImage: "arrow.2.squarepath")
            Spacer()
            Image(systemName: "star.fill").foregroundStyle(.orange)
            Label("\(views)", systemImage: "eye")
        }
        .foregroundStyle(.secondary)
        .font(.system(size: 16))
    }
}
