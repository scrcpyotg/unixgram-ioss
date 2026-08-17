import SwiftUI

struct StatsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(["Просмотры", "Подписчики", "Реакции", "Публикации"], id: \.self) { title in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).foregroundStyle(.secondary)
                            Text(Int.random(in: 20...999).formatted())
                                .font(.system(size: 34, weight: .bold))
                        }
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 34))
                            .foregroundStyle(UGTheme.blue)
                    }
                    .padding(22)
                    .background(UGTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(UGTheme.bg)
        .navigationTitle("Статистика")
    }
}
