import SwiftUI

struct MessagesView: View {
    @State private var selectedFilter = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack {
                    Text("Сообщения")
                        .font(.system(size: 31, weight: .regular))
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 25))
                    Image(systemName: "ellipsis")
                        .font(.system(size: 25))
                        .padding(.leading, 18)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                HStack(spacing: 22) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .stroke(LinearGradient(colors: [.green, .cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 68, height: 68)
                            .overlay(Image(systemName: "scribble.variable").font(.title3))
                        Circle()
                            .fill(.purple)
                            .frame(width: 24, height: 24)
                            .overlay(Image(systemName: "plus").font(.caption.bold()))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No active stories yet.")
                            .foregroundStyle(.secondary)
                        Text("My story")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                HStack(spacing: 12) {
                    filterButton("Все", 0)
                    filterButton("Закреплённые", 1)
                    filterButton("Архив", 2)
                    Button {} label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 30)

                Spacer()

                Text("Пока нет сообщений.")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Button {} label: {
                Image(systemName: "pencil")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color(red: 0.43, green: 0.32, blue: 0.88))
                    .clipShape(Circle())
            }
            .padding(.trailing, 28)
            .padding(.bottom, 26)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func filterButton(_ title: String, _ index: Int) -> some View {
        Button {
            selectedFilter = index
        } label: {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(selectedFilter == index ? Color(red: 0.65, green: 0.52, blue: 1.0) : .secondary)
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(selectedFilter == index ? Color.purple.opacity(0.15) : Color.clear)
                .clipShape(Capsule())
        }
    }
}
