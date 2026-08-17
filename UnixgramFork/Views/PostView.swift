import SwiftUI

struct PostView: View {
    @State private var filter = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                    Text("Пост")
                        .font(.system(size: 31, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.gray.opacity(0.4))
                            .frame(width: 56, height: 56)
                            .overlay(Image(systemName: "tree.fill"))
                        Text("deyyyness141")
                            .font(.system(size: 21, weight: .bold))
                        Text("@deyyyness · 48 мин.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }

                    Text("кто багажный- ❤️")
                        .font(.system(size: 21))

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.9), .pink.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 520)
                        .overlay {
                            VStack(spacing: 18) {
                                Text("Emodzi Unixgram")
                                    .font(.system(size: 28, weight: .bold))
                                Text("Media placeholder")
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }

                    HStack(spacing: 24) {
                        Label("3", systemImage: "heart.fill").foregroundStyle(UGTheme.pink)
                        Label("0", systemImage: "bubble.left")
                        Label("0", systemImage: "arrow.2.squarepath")
                        Spacer()
                        Label("13", systemImage: "eye")
                    }
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(UGTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    filterButton("Новые", 0)
                    filterButton("Старые", 1)
                    filterButton("Популярные", 2)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 30)
        }
        .background(UGTheme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func filterButton(_ title: String, _ index: Int) -> some View {
        Button {
            filter = index
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 22)
                .frame(height: 52)
                .background(filter == index ? UGTheme.surface2 : Color.clear)
                .clipShape(Capsule())
        }
        .foregroundStyle(.white)
    }
}
