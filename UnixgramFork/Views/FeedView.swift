import SwiftUI

struct FeedView: View {
    var body: some View {
        List {
            ForEach(0..<10) { i in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 42, height: 42)
                        VStack(alignment: .leading) {
                            Text("Channel \(i + 1)").bold()
                            Text("now").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Пост в социальной ленте Unixgram. Здесь будет реальный контент после подключения документированных API-методов.")
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.thinMaterial)
                        .frame(height: 180)
                    HStack {
                        Label("\(21+i)", systemImage: "heart")
                        Spacer()
                        Label("\(4+i)", systemImage: "bubble.right")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Feed")
    }
}
