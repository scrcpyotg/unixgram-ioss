import SwiftUI

struct CreatorStudioView: View {
    @State private var paidSubscription = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "chevron.left").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Студия креатора")
                            .font(.system(size: 25, weight: .bold))
                        Text("Аналитика и монетизация")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)

                Divider().overlay(Color.white.opacity(0.08))

                BalanceCard()
                    .padding(.horizontal, 18)

                VStack(alignment: .leading, spacing: 14) {
                    Text("МОНЕТИЗАЦИЯ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)
                        .padding(.horizontal, 22)

                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 54, height: 54)
                                .overlay(Image(systemName: "sparkles").foregroundStyle(.yellow))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Платная подписка")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Доступ к закрытым постам за звёзды каждый месяц")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 16))
                            }
                            Spacer()
                            Toggle("", isOn: $paidSubscription)
                                .labelsHidden()
                        }
                        .padding(18)

                        Divider().overlay(Color.white.opacity(0.08))

                        HStack {
                            Label("Активных подписчиков", systemImage: "person.2")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0").bold()
                        }
                        .padding(18)
                    }
                    .background(UGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 18)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("ОБЗОР · 30 ДНЕЙ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)
                        .padding(.horizontal, 22)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        MetricCard(icon: "chart.line.uptrend.xyaxis", title: "Просмотры", value: "36", tint: .cyan)
                        MetricCard(icon: "person.2", title: "Подписчики", value: "2", tint: .green)
                        MetricCard(icon: "sparkles", title: "Заработано ⭐", value: "0", tint: .yellow)
                        MetricCard(icon: "heart", title: "Вовлечённость", value: "5", tint: .pink)
                        MetricCard(icon: "chart.bar", title: "Постов", value: "3", tint: .secondary)
                        MetricCard(icon: "sparkles", title: "Спонсоров", value: "0", tint: .yellow)
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 28)
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct BalanceCard: View {
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 92, height: 92)
                .overlay(Image(systemName: "sparkles").font(.system(size: 38, weight: .semibold)).foregroundStyle(.white))

            Text("0")
                .font(.system(size: 60, weight: .semibold))

            Text("звёзд на балансе")
                .foregroundStyle(.secondary)
                .font(.system(size: 18))

            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.yellow)
                Text("+0 за 30 дней")
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.18), UGTheme.surface],
                startPoint: .topLeading,
                endPoint: .center
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .background(UGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .stroke(tint.opacity(0.08))
        }
    }
}
