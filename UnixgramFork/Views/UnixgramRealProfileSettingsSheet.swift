import SwiftUI

struct UnixgramRealProfileSettingsSheet: View {
    @Binding var isPresented: Bool
    let user: UGCurrentAccount

    @State private var tab: RealSettingsTab = .profile

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 78, height: 6)
                .padding(.top, 12)
                .padding(.bottom, 18)

            HStack(spacing: 22) {
                ForEach(RealSettingsTab.allCases, id: \.rawValue) { item in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            tab = item
                        }
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(tab == item ? Color.black : Color.secondary)
                            .frame(width: 48, height: 48)
                            .background(tab == item ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.bottom, 18)

            Divider()
                .overlay(Color.white.opacity(0.10))
                .padding(.horizontal, 24)

            Group {
                switch tab {
                case .profile:
                    RealProfileEditPane(user: user)
                case .appearance:
                    RealAppearancePane(user: user)
                case .music:
                    RealMusicPane()
                case .security:
                    RealSecurityPane(user: user)
                case .privacy:
                    RealPrivacyPane(user: user)
                case .notifications:
                    RealNotificationsPane()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.025, green: 0.025, blue: 0.032))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
        .overlay {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .stroke(Color.white.opacity(0.12))
        }
    }
}

private enum RealSettingsTab: Int, CaseIterable {
    case profile, appearance, music, security, privacy, notifications

    var icon: String {
        switch self {
        case .profile: "person"
        case .appearance: "paintpalette"
        case .music: "powerplug"
        case .security: "shield"
        case .privacy: "hand.raised"
        case .notifications: "bell"
        }
    }
}

private struct RealProfileEditPane: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    let user: UGCurrentAccount

    @State private var displayName: String
    @State private var bio: String
    @State private var location: String
    @State private var website: String
    @State private var aliases: String
    @State private var birthDate: String

    init(user: UGCurrentAccount) {
        self.user = user
        _displayName = State(initialValue: user.displayName ?? "")
        _bio = State(initialValue: user.bio ?? "")
        _location = State(initialValue: user.location ?? "")
        _website = State(initialValue: user.website ?? "")
        _aliases = State(initialValue: user.usernameAliases?.joined(separator: ", ") ?? "")
        _birthDate = State(initialValue: user.birthDate ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                preview

                sectionTitle("Основное")
                labeledField("Имя", text: $displayName)
                labeledReadOnly("Username", value: "@\(user.username)")
                labeledField("О себе", text: $bio)
                labeledField("Город", text: $location)
                labeledField("Сайт", text: $website)

                Divider().overlay(Color.white.opacity(0.10))

                sectionTitle("Доп. теги")
                Text("Реальные aliases из аккаунта Unixgram")
                    .foregroundStyle(.secondary)
                labeledField("Aliases", text: $aliases)

                Divider().overlay(Color.white.opacity(0.10))

                sectionTitle("Дата рождения")
                labeledField("Дата", text: $birthDate)

                Divider().overlay(Color.white.opacity(0.10))

                UnixgramVerificationStatusView()

                Divider().overlay(Color.white.opacity(0.10))

                sectionTitle("Аккаунт")
                infoRow("Почта", user.email ?? "—")
                infoRow("Роль", user.role ?? "—")
                if let number = user.registrationNumber {
                    infoRow("Номер регистрации", "#\(number)")
                }
                infoRow("Premium", user.premium == true ? "Да" : "Нет")

                Button {
                    Task { await liveSession.refreshAuthentication() }
                } label: {
                    Label("Обновить с сервера", systemImage: "arrow.clockwise")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text("Поля заполнены настоящими данными `/api/auth/me`. В HAR пока не было запроса сохранения профиля, поэтому изменения полей не отправляются на сервер — не подменяю неизвестный endpoint догадкой.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
    }

    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let raw = user.coverUrl, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: Color.white.opacity(0.04)
                        }
                    }
                } else {
                    Color.white.opacity(0.04)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 26))

            HStack(spacing: 14) {
                Group {
                    if let raw = user.avatarUrl, let url = URL(string: raw) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            default: Circle().fill(.blue)
                            }
                        }
                    } else {
                        Circle().fill(.blue)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())

                VStack(alignment: .leading) {
                    Text(user.displayName ?? user.username)
                        .font(.system(size: 22, weight: .bold))
                    Text("@\(user.username)")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 23, weight: .bold))
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text)
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func labeledReadOnly(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 56)
                .background(Color.white.opacity(0.018))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08)))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .padding(.vertical, 6)
    }
}

private struct RealAppearancePane: View {
    let user: UGCurrentAccount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Оформление")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.premium == true ? "Unix Premium активен" : "Unix Premium не активен")
                            .font(.system(size: 19, weight: .semibold))
                        Text("Лимиты оформления зависят от статуса аккаунта.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("В demo UI здесь были цветовые схемы и особые значки. `/api/auth/me` не возвращает выбранную схему/мемные badges, поэтому сейчас не показываю фиктивно выбранные значения.")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(["Default", "Champagne", "Ice Blue", "Blue", "Violet", "Cyan", "Emerald", "Pink", "Orange", "Gold", "Platinum", "Red"], id: \.self) { name in
                        HStack {
                            Circle()
                                .fill(color(for: name))
                                .frame(width: 36, height: 36)
                            Text(name)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 68)
                        .background(Color.white.opacity(0.025))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10)))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func color(for name: String) -> Color {
        switch name {
        case "Champagne": return Color(red: 0.78, green: 0.70, blue: 0.56)
        case "Ice Blue": return .blue
        case "Blue": return .indigo
        case "Violet": return .purple
        case "Cyan": return .cyan
        case "Emerald": return .green
        case "Pink": return .pink
        case "Orange": return .orange
        case "Gold": return .yellow
        case "Platinum": return Color(red: 0.80, green: 0.83, blue: 0.89)
        case "Red": return .red
        default: return .white
        }
    }
}

private struct RealMusicPane: View {
    @State private var integrations: [UGIntegration] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Музыкальные сервисы")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                if loading {
                    ProgressView("Загружаем подключения…")
                } else {
                    ForEach(integrations) { item in
                        integrationCard(item)
                    }

                    if integrations.isEmpty {
                        Text("Unixgram не вернул доступных интеграций.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .task { await load() }
    }

    private func integrationCard(_ item: UGIntegration) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(tint(item.provider).opacity(0.16))
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(tint(item.provider))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName(item.provider))
                    .font(.system(size: 20, weight: .semibold))
                Text(item.connected ? (item.accountName ?? "Подключено") : "Не подключено")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.connected ? "Подключено" : (item.available ? "Доступно" : "Недоступно"))
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12)))
    }

    private func load() async {
        do {
            integrations = try await UnixgramRealAPIClient.shared.integrations()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func displayName(_ provider: String) -> String {
        provider == "spotify" ? "Spotify" :
        provider == "soundcloud" ? "SoundCloud" :
        provider.capitalized
    }

    private func tint(_ provider: String) -> Color {
        provider == "spotify" ? .green :
        provider == "soundcloud" ? .orange : .blue
    }
}

private struct RealSecurityPane: View {
    let user: UGCurrentAccount
    @State private var sessions: [UGAccountSession] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Безопасность")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                securityRow(
                    icon: "envelope",
                    title: "Почта",
                    subtitle: user.email ?? "Не указана",
                    status: user.emailVerifiedAt == nil ? "Не подтверждена" : "Подтверждена"
                )

                securityRow(
                    icon: "lock.shield",
                    title: "Двухфакторная защита",
                    subtitle: twoFactorSubtitle,
                    status: user.twoFactorEnabled == true ? "Включена" : "Выключена"
                )

                Divider().overlay(Color.white.opacity(0.10))

                Text("Активные сессии")
                    .font(.system(size: 22, weight: .bold))

                if loading {
                    ProgressView("Загружаем устройства…")
                } else {
                    ForEach(sessions) { session in
                        sessionCard(session)
                    }
                }

                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .task { await load() }
    }

    private var twoFactorSubtitle: String {
        guard user.twoFactorEnabled == true else { return "Не настроена" }
        switch user.twoFactorMethod {
        case "app": return "Приложение-аутентификатор"
        case "email": return "Код по электронной почте"
        default: return user.twoFactorMethod ?? "Включена"
        }
    }

    private func securityRow(icon: String, title: String, subtitle: String, status: String) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: icon))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            Text(status)
                .font(.caption.bold())
                .foregroundStyle(.cyan)
        }
        .padding(.vertical, 8)
    }

    private func sessionCard(_ session: UGAccountSession) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12))
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: deviceIcon(session.platform))
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.deviceName ?? deviceName(session.platform))
                        .font(.system(size: 17, weight: .semibold))
                    if session.current {
                        Text("Это устройство")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                    }
                }

                Text(session.source ?? "Unixgram")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let date = session.lastSeenAt {
                    Text("Последняя активность: \(friendlyDate(date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(session.current ? Color.cyan.opacity(0.05) : Color.white.opacity(0.025))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(session.current ? Color.cyan.opacity(0.16) : Color.white.opacity(0.08)))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func load() async {
        do {
            sessions = try await UnixgramRealAPIClient.shared.accountSessions()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func deviceName(_ platform: String?) -> String {
        guard let platform else { return "Неизвестное устройство" }
        if platform.localizedCaseInsensitiveContains("iPhone") { return "iPhone" }
        if platform.localizedCaseInsensitiveContains("Windows") { return "Windows PC" }
        if platform.localizedCaseInsensitiveContains("Mac") { return "Mac" }
        return "Устройство Unixgram"
    }

    private func deviceIcon(_ platform: String?) -> String {
        guard let platform else { return "desktopcomputer" }
        if platform.localizedCaseInsensitiveContains("iPhone") { return "iphone" }
        return "desktopcomputer"
    }

    private func friendlyDate(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct RealPrivacyPane: View {
    let user: UGCurrentAccount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Приватность")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                info("Язык аккаунта", user.language?.uppercased() ?? "—", icon: "globe")
                info("Профиль", user.isActive == true ? "Активен" : "Неактивен", icon: "person.crop.circle")
                info("Статус Premium", user.premium == true ? "Premium" : "Обычный", icon: "sparkles")

                Divider().overlay(Color.white.opacity(0.10))

                Text("Настройки онлайн-статуса, платных сообщений, скриншотов и blacklist были в demo UI. В захваченном API нет их текущих значений, поэтому здесь не показываются фиктивные Toggle-состояния.")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func info(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.04))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RealNotificationsPane: View {
    @State private var prefs: UGNotificationPreferences?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Уведомления")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                if loading {
                    ProgressView("Загружаем настройки…")
                        .padding(.vertical, 24)
                } else if let prefs {
                    readToggle("Все уведомления", value: prefs.enabled)
                    readToggle("Звук", value: prefs.sound)
                    divider()
                    readToggle("Лайки", value: prefs.likes)
                    readToggle("Комментарии", value: prefs.comments)
                    readToggle("Репосты", value: prefs.reposts)
                    readToggle("Упоминания", value: prefs.mentions)
                    readToggle("Подписки", value: prefs.follows)
                    readToggle("Подарки", value: prefs.gifts)
                    readToggle("Донаты", value: prefs.donations)
                    readToggle("Просмотры профиля", value: prefs.profileViews)
                    readToggle("Новые посты", value: prefs.newPosts)
                    readToggle("Новые Stories", value: prefs.newStories)
                    readToggle("Ответы на Stories", value: prefs.storyReplies)

                    Text("Это реальные значения `/api/social/notifications/preferences`. В HAR не был захвачен endpoint изменения preferences, поэтому переключатели пока только отображают серверное состояние.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding(.top, 18)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
        .task { await load() }
    }

    private func readToggle(_ title: String, value: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 18, weight: .semibold))
            Spacer()
            Toggle("", isOn: .constant(value))
                .labelsHidden()
                .disabled(true)
        }
        .padding(.vertical, 14)
    }

    private func divider() -> some View {
        Divider().overlay(Color.white.opacity(0.10))
    }

    private func load() async {
        do {
            prefs = try await UnixgramRealAPIClient.shared.notificationPreferences()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
