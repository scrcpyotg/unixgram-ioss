import SwiftUI

struct StoriesView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<6) { i in
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 520)
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading) {
                                Text("Story \(i + 1)")
                                    .font(.title2.bold())
                                Text("Unixgram-style story placeholder")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(22)
                        }
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Stories")
    }
}
