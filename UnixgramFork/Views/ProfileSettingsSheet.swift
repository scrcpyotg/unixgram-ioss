import SwiftUI

enum ProfileSettingsTab: Int, CaseIterable {
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

struct ProfileSettingsSheet: View {
    @Binding var isPresented: Bool
    @State private var tab: ProfileSettingsTab = .profile

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 78, height: 6)
                .padding(.top, 12)
                .padding(.bottom, 18)

            HStack(spacing: 22) {
                ForEach(ProfileSettingsTab.allCases, id: \.rawValue) { item in
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

            Divider().overlay(Color.white.opacity(0.10))
                .padding(.horizontal, 24)

            Group {
                switch tab {
                case .profile: ProfileEditPane()
                case .appearance: AppearancePane()
                case .music: MusicServicesPane()
                case .security: SecurityPane()
                case .privacy: PrivacyPane()
                case .notifications: NotificationsPane()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(red: 0.025, green: 0.025, blue: 0.032))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .stroke(Color.white.opacity(0.12))
        )
    }
}

private struct PrivacyPane: View {
    @State private var online = true
    @State private var paidMessages = false
    @State private var screenshotAlerts = false
    @State private var language = "Русский"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Приватность")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                settingToggle("Онлайн-статус", subtitle: "Показывать время последнего визита", value: $online)
                divider()
                settingToggle("Платные сообщения", subtitle: "Те, на кого вы не подписаны, платят звёздами за первое сообщение вам. Звёзды приходят вам.", value: $paidMessages)
                divider()
                settingToggle("Оповещать о скриншотах", subtitle: "Доступно только с Premium.", value: $screenshotAlerts)
                divider()

                Text("Язык приложения")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, 20)
                Text("Язык сохранится в профиле и применится после обновления.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                HStack {
                    Text("🇷🇺")
                    Text(language)
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 58)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
                .padding(.top, 16)

                divider().padding(.vertical, 22)

                Text("ЧЁРНЫЙ СПИСОК")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text("Чёрный список пуст")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func settingToggle(_ title: String, subtitle: String, value: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: value)
                .labelsHidden()
        }
        .padding(.vertical, 20)
    }

    private func divider() -> some View {
        Divider().overlay(Color.white.opacity(0.10))
    }
}

private struct SecurityPane: View {
    @State private var privateAccount = false
    @State private var groupPolicy = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Безопасность")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Закрытый аккаунт")
                            .font(.system(size: 19, weight: .semibold))
                        Text("Ваш профиль и записи открыты всем.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $privateAccount).labelsHidden()
                }
                .padding(.vertical, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Кто может добавлять меня в беседы")
                        .font(.system(size: 19, weight: .semibold))
                    Text("Остальные смогут только прислать вам ссылку-приглашение.")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        policy("Все", 0)
                        policy("Мои подписки", 1)
                        policy("Никто", 2)
                    }
                }
                .padding(.bottom, 22)

                divider()

                actionRow("Пароль", subtitle: "Изменить пароль от аккаунта", button: "Сменить пароль")
                divider()
                iconRow("envelope", "Вход по почте", subtitle: "Подтверждайте вход одноразовым кодом с почты")
                divider()
                actionRow("Подключить устройство", subtitle: "Отсканируйте QR-код, чтобы войти в аккаунт на компьютере или планшете", button: "Сканировать", icon: "qrcode.viewfinder")
                divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Активные сессии")
                        .font(.system(size: 20, weight: .bold))
                    Text("Устройства, на которых сейчас выполнен вход в ваш аккаунт")
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12))
                            .frame(width: 58, height: 58)
                            .overlay(Image(systemName: "desktopcomputer").font(.title3))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Неизвестное устройство")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Это устройство")
                                    .font(.caption.bold())
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 8)
                                    .frame(height: 24)
                                    .background(Color.cyan.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Text("1 час назад").foregroundStyle(.secondary)
                        }
                    }
                    .padding(18)
                    .background(Color.cyan.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cyan.opacity(0.16)))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 12)
                }
                .padding(.top, 22)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func policy(_ title: String, _ idx: Int) -> some View {
        Button {
            groupPolicy = idx
        } label: {
            Text(title)
                .foregroundStyle(groupPolicy == idx ? .cyan : .white)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(groupPolicy == idx ? Color.cyan.opacity(0.12) : Color.clear)
                .overlay(Capsule().stroke(Color.white.opacity(0.12)))
                .clipShape(Capsule())
        }
    }

    private func actionRow(_ title: String, subtitle: String, button: String, icon: String? = nil) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 19, weight: .semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            Button {} label: {
                HStack(spacing: 8) {
                    if let icon { Image(systemName: icon) }
                    Text(button).fontWeight(.bold)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .background(.white)
                .clipShape(Capsule())
            }
        }
        .padding(.vertical, 18)
    }

    private func iconRow(_ icon: String, _ title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: icon))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            ProgressView()
        }
        .padding(.vertical, 16)
    }

    private func divider() -> some View { Divider().overlay(Color.white.opacity(0.10)) }
}

private struct MusicServicesPane: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Музыкальные сервисы")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 20)

                Text("Подключите сервис, чтобы прикреплять песни к постам — из своих плейлистов или поиском по названию.")
                    .foregroundStyle(.secondary)

                service("music.note", "Spotify", "Не подключено", button: "Подключить", tint: .green)
                service("music.note", "SoundCloud", "Вставьте ссылку на трек и…", button: "Открыть", tint: .orange)

                Divider().overlay(Color.white.opacity(0.10))

                Text("В посте играет 30-секундный отрывок, который отдаёт сам сервис. Если у трека его нет, карточка предложит открыть песню в Spotify или SoundCloud — полное воспроизведение доступно только в их собственных приложениях.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func service(_ icon: String, _ title: String, _ subtitle: String, button: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: icon).foregroundStyle(tint))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            Spacer()
            Button(button) {}
                .fontWeight(.bold)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(button == "Подключить" ? tint : Color.white.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12)))
    }
}

private struct AppearancePane: View {
    @State private var selectedScheme = "Emerald"
    @State private var selectedBadge: Set<String> = ["Эстет уровня бог", "Холодный как лёд", "Мыслитель"]

    let schemes: [(String, Color)] = [
        ("Default", .white), ("Champagne", Color(red: 0.78, green: 0.70, blue: 0.56)),
        ("Ice Blue", .blue), ("Blue", .indigo),
        ("Violet", .purple), ("Cyan", .cyan),
        ("Emerald", .green), ("Pink", .pink),
        ("Orange", .orange), ("Gold", .yellow),
        ("Platinum", Color(red: 0.80, green: 0.83, blue: 0.89)), ("Red", .red)
    ]

    let badges = [
        ("Воздухан", "wind", Color.gray),
        ("Телеграм воин", "paperplane.fill", .blue),
        ("Лучший из лучших", "crown.fill", .yellow),
        ("Эстет уровня бог", "diamond.fill", .purple),
        ("Настоящий 100%", "100.square.fill", .pink),
        ("Инопланетянин", "aqi.medium", .green),
        ("Доброе сердце", "heart.fill", .pink),
        ("Холодный как лёд", "snowflake", .cyan),
        ("Анонимный герой", "theatermasks.fill", .gray),
        ("Фотограф", "camera.fill", .blue),
        ("Эколог", "leaf.fill", .green),
        ("Путешественник", "airplane", .cyan),
        ("Писатель", "book.fill", .purple),
        ("Спортсмен", "figure.run", .orange),
        ("Шеф-повар", "frying.pan.fill", .red),
        ("Учёный", "testtube.2", .blue),
        ("Мыслитель", "brain.head.profile", .purple),
        ("Криптоэнтузиаст", "bitcoinsign.circle.fill", .yellow)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Цветовая схема профиля")
                    .font(.system(size: 20, weight: .bold))
                    .padding(.top, 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(schemes, id: \.0) { item in
                        Button {
                            selectedScheme = item.0
                        } label: {
                            HStack {
                                Circle().fill(item.1).frame(width: 38, height: 38)
                                Text(item.0).foregroundStyle(.white)
                                Spacer()
                                if selectedScheme == item.0 {
                                    Image(systemName: "checkmark").foregroundStyle(.cyan)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 72)
                            .background(selectedScheme == item.0 ? Color.cyan.opacity(0.10) : Color.white.opacity(0.025))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }

                HStack {
                    Text("Особые галочки")
                        .font(.system(size: 24, weight: .bold))
                    Spacer()
                    Text("\(selectedBadge.count)/3")
                        .foregroundStyle(.secondary)
                }

                Text("Можно поставить себе самому — до 3 без Premium, до 7 с Unix Premium. Официальные галочки и достижения выдаёт только система.")
                    .foregroundStyle(.secondary)

                Text("ОСОБЫЕ И МЕМНЫЕ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { idx, item in
                        badgeCard(item.0, icon: item.1, tint: item.2)
                        if idx == 8 {
                            Color.clear.frame(height: 0)
                        }
                    }
                }

                Button("Сохранить") {}
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func badgeCard(_ title: String, icon: String, tint: Color) -> some View {
        let selected = selectedBadge.contains(title)
        return Button {
            if selected {
                selectedBadge.remove(title)
            } else if selectedBadge.count < 3 {
                selectedBadge.insert(title)
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(selected ? Color.cyan.opacity(0.10) : Color.white.opacity(0.025))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct ProfileEditPane: View {
    @State private var interests = "аниме, музыка, спорт"
    @State private var tags = "aeternaldeV, regret, vivid, exg888, aloha, akiko, elio, velvet, soulless, doomed"
    @State private var birthDate = ""
    @State private var selectedCoverTab = 2
    @State private var scheme = "Emerald"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.gray.opacity(0.5), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 26))

                    HStack(spacing: 14) {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 90, height: 90)
                            .overlay(Image(systemName: "scribble.variable").font(.system(size: 40)))
                        VStack(alignment: .leading) {
                            Text("aeternaldeV").font(.system(size: 22, weight: .bold))
                            Text("@aeternal").foregroundStyle(.secondary)
                        }
                    }
                    .padding(18)
                }

                HStack {
                    coverTab("paintpalette", "Цвет", 0)
                    coverTab("photo", "Фото", 1)
                    coverTab("video", "Видео", 2)
                    coverTab("gift", "Гифт", 3)
                }

                Button {
                } label: {
                    Label("Заменить видео", systemImage: "square.and.arrow.up")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                }

                Text("Короткий ролик до 25 МБ. Воспроизводится без звука по кругу.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text("Интересы")
                    .font(.system(size: 23, weight: .bold))
                Text("Помогают находить похожих людей. Через запятую: аниме, программирование")
                    .foregroundStyle(.secondary)
                field($interests)

                Divider().overlay(Color.white.opacity(0.10))

                Text("Доп. теги")
                    .font(.system(size: 23, weight: .bold))
                Text("Дополнительные @теги через запятую")
                    .foregroundStyle(.secondary)
                field($tags)
                Text("10 из 10").foregroundStyle(.secondary)

                Divider().overlay(Color.white.opacity(0.10))

                Text("Ссылки")
                    .font(.system(size: 23, weight: .bold))
                Text("Соцсети, сайт или шоп — до 6 ссылок. Иконка подбирается автоматически.")
                    .foregroundStyle(.secondary)
                dashedButton("Добавить ссылку")

                Divider().overlay(Color.white.opacity(0.10))

                Text("Каналы в профиле")
                    .font(.system(size: 23, weight: .bold))
                Text("Каналы, которыми вы управляете, — до 3 в профиле.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    Circle()
                        .fill(LinearGradient(colors: [.cyan, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 54, height: 54)
                        .overlay(Text("↳").font(.title2.bold()))
                    VStack(alignment: .leading) {
                        Text("aeternal").font(.system(size: 18, weight: .bold))
                        Text("@menace").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .padding(14)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
                dashedButton("Добавить канал")

                Divider().overlay(Color.white.opacity(0.10))

                Text("Дата рождения")
                    .font(.system(size: 23, weight: .bold))
                HStack {
                    TextField("Выбрать дату", text: $birthDate)
                    Spacer()
                    Image(systemName: "calendar").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 58)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))

                Button("Сохранить") {}
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Button {} label: {
                    Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.pink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10)))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Опасная зона")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.pink)
                    Text("Удаление аккаунта необратимо: будут навсегда удалены профиль, посты, сообщения, подписки и подарки.")
                        .foregroundStyle(.secondary)
                    Button("Удалить аккаунт") {}
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.pink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.pink.opacity(0.20)))
                }
                .padding(20)
                .background(Color.red.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    private func coverTab(_ icon: String, _ title: String, _ idx: Int) -> some View {
        Button {
            selectedCoverTab = idx
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(selectedCoverTab == idx ? Color.black : Color.secondary)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(selectedCoverTab == idx ? .white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func field(_ text: Binding<String>) -> some View {
        TextField("", text: text)
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(Color.white.opacity(0.025))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func dashedButton(_ title: String) -> some View {
        Button {} label: {
            Label(title, systemImage: "plus")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
        }
    }
}

private struct NotificationsPane: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Не удалось загрузить настройки. Закройте и откройте окно ещё раз.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 36)
            Spacer()
        }
    }
}
