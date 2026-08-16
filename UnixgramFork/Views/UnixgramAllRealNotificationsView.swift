import SwiftUI

struct UnixgramAllRealNotificationsView: View {
    @EnvironmentObject private var store: UnixgramLiveDashboardStore
    @State private var prefs: UGNotificationPreferences?
    @State private var loadingPrefs = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Уведомления")
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    Text("\(store.notificationUnread)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(.purple)
                        .clipShape(Capsule())
                }

                summaryCard

                if let prefs {
                    Text("Настройки")
                        .font(.system(size: 22, weight: .bold))

                    preference("Лайки", prefs.likes)
                    preference("Комментарии", prefs.comments)
                    preference("Репосты", prefs.reposts)
                    preference("Упоминания", prefs.mentions)
                    preference("Подписки", prefs.follows)
                    preference("Подарки", prefs.gifts)
                    preference("Донаты", prefs.donations)
                    preference("Просмотры профиля", prefs.profileViews)
                    preference("Новые посты", prefs.newPosts)
                    preference("Новые Stories", prefs.newStories)
                    preference("Ответы Stories", prefs.storyReplies)
                } else if loadingPrefs {
                    ProgressView("Загружаем preferences…")
                }

                Text("Список самих notification items в HAR не был загружен отдельным GET-методом. Поэтому здесь показаны реальные unread count и реальные preferences, без выдуманного списка уведомлений.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }
            .padding(18)
        }
        .background(Color.black)
        .task { await load() }
        .refreshable { await load() }
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: store.notificationUnread > 0 ? "bell.badge.fill" : "bell.fill")
                .font(.system(size: 28))
                .foregroundStyle(.purple)
                .frame(width: 58, height: 58)
                .background(Color.purple.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(store.notificationUnread > 0 ? "Есть непрочитанные" : "Всё просмотрено")
                    .font(.system(size: 19, weight: .bold))
                Text("Unixgram сообщает: \(store.notificationUnread)")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func preference(_ title: String, _ value: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: .constant(value))
                .labelsHidden()
                .disabled(true)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        loadingPrefs = true
        defer { loadingPrefs = false }

        await store.refreshAll()
        prefs = try? await UnixgramRealAPIClient.shared.notificationPreferences()
    }
}
