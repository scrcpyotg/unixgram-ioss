import SwiftUI

struct ChannelDetailView: View {
    let channel: CommunityItem
    @State private var tab = 0
    @State private var draft = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.76), Color.gray.opacity(0.35), Color.black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 290)
                    .overlay {
                        Text("aeternal")
                            .font(.system(size: 42, weight: .light, design: .serif))
                            .foregroundStyle(.black.opacity(0.35))
                    }

                    Button {} label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 21, weight: .bold))
                            .frame(width: 48, height: 48)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 118, height: 118)
                            .overlay {
                                Text("↳")
                                    .font(.system(size: 48, weight: .bold))
                            }
                            .offset(y: -58)
                            .padding(.bottom, -58)

                        Spacer()

                        Button {} label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text("Управление")
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 48)
                            .overlay(Capsule().stroke(Color.white.opacity(0.14)))
                        }
                        .foregroundStyle(.white)
                    }

                    Text(channel.name)
                        .font(.system(size: 28, weight: .bold))

                    Text(channel.handle)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)

                    Text("devlog")
                        .font(.system(size: 19))

                    HStack(spacing: 10) {
                        Text("aeternaldeV")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Владелец")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(UGTheme.surface2)
                    .clipShape(Capsule())

                    HStack(spacing: 12) {
                        Text("# ipa java html разработка")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(UGTheme.surface2)
                            .clipShape(Capsule())

                        Label("munhem", systemImage: "location")
                            .foregroundStyle(.secondary)
                    }

                    Label("Создан 16 авг. 2026 г.", systemImage: "calendar")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 30) {
                        Text("1 ").bold() + Text("подписчиков").foregroundColor(.secondary)
                        Text("0 ").bold() + Text("публикаций").foregroundColor(.secondary)
                    }
                    .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("ПОДАРКИ", systemImage: "gift")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("Подписчики смогут дарить подарки каналу.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)

                Divider().overlay(Color.white.opacity(0.10))

                HStack {
                    channelTab("Посты", 0)
                    channelTab("Истории", 1)
                    channelTab("Медиа", 2)
                    channelTab("Подарки", 3)
                }
                .padding(.horizontal, 10)

                Divider().overlay(Color.white.opacity(0.08))

                if tab == 0 {
                    ChannelComposer(draft: $draft)
                    EmptyChannelState()
                } else {
                    EmptyChannelState(title: "Пока пусто", subtitle: "Здесь появится содержимое раздела.")
                }
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func channelTab(_ title: String, _ index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { tab = index }
        } label: {
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tab == index ? Color.white : Color.secondary)
                Rectangle()
                    .fill(tab == index ? UGTheme.blue : .clear)
                    .frame(height: 4)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ChannelComposer: View {
    @Binding var draft: String

    var body: some View {
        VStack(spacing: 14) {
            TextField("Написать в канал…", text: $draft, axis: .vertical)
                .font(.system(size: 19))
                .lineLimit(1...5)

            HStack(spacing: 22) {
                ForEach(["photo.badge.plus", "film", "doc", "doc.text"], id: \.self) { icon in
                    Image(systemName: icon)
                        .foregroundStyle(.cyan)
                        .font(.system(size: 21))
                }
                Spacer()
                Button {} label: {
                    HStack {
                        Image(systemName: "paperplane")
                        Text("Опубликовать")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.58))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(22)
    }
}

private struct EmptyChannelState: View {
    var title: String = "Пока нет публикаций"
    var subtitle: String = "Опубликуйте первый пост канала."

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 72, height: 72)
                .overlay(Image(systemName: "doc.text").font(.title2).foregroundStyle(.secondary))

            Text(title)
                .font(.system(size: 21, weight: .bold))

            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
        .padding(.bottom, 160)
    }
}
