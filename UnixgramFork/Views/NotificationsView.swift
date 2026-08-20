import SwiftUI

struct UGNotification: Identifiable {
    let id = UUID()
    let name: String
    let action: String
    let subtitle: String?
    let minutes: Int
    let icon: String
    let tint: Color
}

struct NotificationsView: View {
    let items: [UGNotification] = [
        .init(name: "false", action: "оценил(а) вашу запись", subtitle: nil, minutes: 1, icon: "heart.fill", tint: .red),
        .init(name: "696", action: "оформил(а) платную подписку на вас ⭐", subtitle: nil, minutes: 1, icon: "sparkles", tint: .orange),
        .init(name: "696", action: "упомянул вас", subtitle: "@deyyyness чета много", minutes: 1, icon: "at", tint: .orange),
        .init(name: "K1zaru #Killtoxin", action: "оценил(а) вашу запись", subtitle: nil, minutes: 4, icon: "heart.fill", tint: .red),
        .init(name: "возможнаяконструкция", action: "оценил(а) вашу запись", subtitle: nil, minutes: 5, icon: "heart.fill", tint: .red),
        .init(name: "возможнаяконструкция", action: "прокомментировал ваш пост", subtitle: "выглядит хайпова", minutes: 5, icon: "arrowshape.turn.up.left.fill", tint: .purple)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Уведомления")
                        .font(.system(size: 31, weight: .bold))
                    Spacer()
                    Image(systemName: "gearshape")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)

                Divider().overlay(Color.white.opacity(0.14))

                HStack {
                    Text("Непрочитано: ")
                        .foregroundColor(.secondary)
                    + Text("2").bold().foregroundColor(.white)
                    Spacer()
                    Text("Прочитать всё")
                        .font(.system(size: 19))
                }
                .padding(.horizontal, 18)

                HStack {
                    Text("СЕГОДНЯ")
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                ForEach(items) { item in
                    NotificationCard(item: item)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .background(UGTheme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct NotificationCard: View {
    let item: UGNotification

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 62, height: 62)
                    .overlay(Image(systemName: "person.fill"))

                Circle()
                    .fill(item.tint)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(UGTheme.surface2, lineWidth: 3))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).bold() + Text(" \(item.action)")
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
                Text("\(item.minutes)м")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(UGTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
