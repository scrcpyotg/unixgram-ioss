import Foundation
import SwiftUI

struct UnixgramBadgeDefinition: Hashable {
    enum Category: String {
        case official
        case special
        case thematic
        case achievement
        case level
        case status
    }

    let id: String
    let category: Category
    let label: String
    let description: String
    let firstHex: String
    let secondHex: String
    let glyph: String?
    let text: String?
    let assetURL: String?
    let rarity: String?
}

enum UnixgramBadgeRegistry {
    static let all: [String: UnixgramBadgeDefinition] = {
        let items: [UnixgramBadgeDefinition] = [
            .init(id: "official_verified", category: .official, label: "Официально верифицирован", description: "Подтверждённый официальный аккаунт Unixgram.", firstHex: "#e4e6eb", secondHex: "#9aa0a6", glyph: "check", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_public", category: .official, label: "Публичная личность", description: "Признан публичной личностью Unixgram.", firstHex: "#38bdf8", secondHex: "#2563eb", glyph: "check", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_musician", category: .official, label: "Музыкант", description: "Официальный музыкант.", firstHex: "#c084fc", secondHex: "#7c3aed", glyph: "music", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_artist", category: .official, label: "Художник", description: "Официальный художник.", firstHex: "#4ade80", secondHex: "#16a34a", glyph: "brush", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_videographer", category: .official, label: "Видеограф", description: "Официальный видеограф.", firstHex: "#22d3ee", secondHex: "#0891b2", glyph: "video", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_blogger", category: .official, label: "Блогер", description: "Официальный блогер.", firstHex: "#fb923c", secondHex: "#ea580c", glyph: "mic", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_expert", category: .official, label: "Эксперт", description: "Признанный эксперт сообщества.", firstHex: "#fcd34d", secondHex: "#d97706", glyph: "cap", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_streamer", category: .official, label: "Стример", description: "Официальный стример.", firstHex: "#f472b6", secondHex: "#db2777", glyph: "gamepad", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_developer", category: .official, label: "Разработчик", description: "Разработчик / технический партнёр.", firstHex: "#60a5fa", secondHex: "#1d4ed8", glyph: "code", text: nil, assetURL: nil, rarity: nil),
            .init(id: "official_sponsor", category: .official, label: "Официальный спонсор", description: "Специальная награда за большой вклад в Unixgram.", firstHex: "#f8d77a", secondHex: "#b77818", glyph: nil, text: nil, assetURL: "https://unixgram.com/badges/official_sponsor.png", rarity: nil),

            .init(id: "meme_air", category: .special, label: "Воздухан", description: "Лёгкий на подъём, как ветер.", firstHex: "#9ca3af", secondHex: "#4b5563", glyph: "wind", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_telegram", category: .special, label: "Телеграм воин", description: "Ветеран мессенджеров.", firstHex: "#38bdf8", secondHex: "#2563eb", glyph: "send", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_best", category: .special, label: "Лучший из лучших", description: "Просто лучший.", firstHex: "#fcd34d", secondHex: "#d97706", glyph: "crown", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_aesthete", category: .special, label: "Эстет уровня бог", description: "Ценитель прекрасного.", firstHex: "#c084fc", secondHex: "#7c3aed", glyph: "gem", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_real", category: .special, label: "Настоящий 100%", description: "На все сто.", firstHex: "#fb7185", secondHex: "#e11d48", glyph: nil, text: "100", assetURL: nil, rarity: nil),
            .init(id: "meme_alien", category: .special, label: "Инопланетянин", description: "Гость с другой планеты.", firstHex: "#a3e635", secondHex: "#65a30d", glyph: "alien", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_kind", category: .special, label: "Доброе сердце", description: "Самый добрый человек.", firstHex: "#f472b6", secondHex: "#db2777", glyph: "heart", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_cold", category: .special, label: "Холодный как лёд", description: "Спокойствие и хладнокровие.", firstHex: "#67e8f9", secondHex: "#0891b2", glyph: "snowflake", text: nil, assetURL: nil, rarity: nil),
            .init(id: "meme_anon", category: .special, label: "Анонимный герой", description: "Тихий герой сообщества.", firstHex: "#6b7280", secondHex: "#1f2937", glyph: "mask", text: nil, assetURL: nil, rarity: nil),

            .init(id: "theme_photographer", category: .thematic, label: "Фотограф", description: "Ловит лучшие кадры.", firstHex: "#60a5fa", secondHex: "#2563eb", glyph: "camera", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_ecologist", category: .thematic, label: "Эколог", description: "За зелёную планету.", firstHex: "#4ade80", secondHex: "#16a34a", glyph: "leaf", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_traveler", category: .thematic, label: "Путешественник", description: "Всегда в пути.", firstHex: "#38bdf8", secondHex: "#0ea5e9", glyph: "plane", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_writer", category: .thematic, label: "Писатель", description: "Мастер слова.", firstHex: "#c084fc", secondHex: "#7c3aed", glyph: "book", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_athlete", category: .thematic, label: "Спортсмен", description: "В здоровом теле — здоровый дух.", firstHex: "#fb923c", secondHex: "#ea580c", glyph: "dumbbell", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_chef", category: .thematic, label: "Шеф-повар", description: "Кулинарный гений.", firstHex: "#fb7185", secondHex: "#dc2626", glyph: "chef", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_scientist", category: .thematic, label: "Учёный", description: "Двигает науку вперёд.", firstHex: "#60a5fa", secondHex: "#1d4ed8", glyph: "flask", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_thinker", category: .thematic, label: "Мыслитель", description: "Глубокие мысли.", firstHex: "#c084fc", secondHex: "#7c3aed", glyph: "brain", text: nil, assetURL: nil, rarity: nil),
            .init(id: "theme_crypto", category: .thematic, label: "Криптоэнтузиаст", description: "Верит в блокчейн.", firstHex: "#fbbf24", secondHex: "#d97706", glyph: "bitcoin", text: nil, assetURL: nil, rarity: nil),

            .init(id: "ach_cold_gaze", category: .achievement, label: "Холодный взгляд", description: "Ничто не ускользнёт от его взгляда.", firstHex: "#67e8f9", secondHex: "#0ea5e9", glyph: "eye", text: nil, assetURL: nil, rarity: "rare"),
            .init(id: "ach_night_player", category: .achievement, label: "Ночной игрок", description: "Активен, когда все спят.", firstHex: "#818cf8", secondHex: "#3730a3", glyph: "moon", text: nil, assetURL: nil, rarity: "uncommon"),
            .init(id: "ach_elusive", category: .achievement, label: "Неуловимый", description: "Здесь был и исчез.", firstHex: "#9ca3af", secondHex: "#374151", glyph: "ghost", text: nil, assetURL: nil, rarity: "epic"),
            .init(id: "ach_silent_watcher", category: .achievement, label: "Молчаливый наблюдатель", description: "Смотрит за всем, не выдавая себя.", firstHex: "#5eead4", secondHex: "#0f766e", glyph: "eyeoff", text: nil, assetURL: nil, rarity: "rare"),
            .init(id: "ach_net_romantic", category: .achievement, label: "Романтик Сети", description: "Сердцеед цифровой эпохи.", firstHex: "#fb7185", secondHex: "#be123c", glyph: "flower", text: nil, assetURL: nil, rarity: "uncommon"),
            .init(id: "ach_drama_queen", category: .achievement, label: "Королева Драмы", description: "Где она — там всегда буря.", firstHex: "#e879f9", secondHex: "#a21caf", glyph: "drama", text: nil, assetURL: nil, rarity: "epic"),
            .init(id: "ach_sniper", category: .achievement, label: "Снайпер", description: "Бьёт точно в цель.", firstHex: "#a3e635", secondHex: "#3f6212", glyph: "crosshair", text: nil, assetURL: nil, rarity: "legendary"),
            .init(id: "ach_lie_killer", category: .achievement, label: "Убийца лжи", description: "Разоблачает любую неправду.", firstHex: "#f87171", secondHex: "#991b1b", glyph: "shieldcheck", text: nil, assetURL: nil, rarity: "legendary"),

            .init(id: "level_novice", category: .level, label: "Новичок", description: "Только начинает путь.", firstHex: "#4b5563", secondHex: "#1f2937", glyph: nil, text: "1", assetURL: nil, rarity: nil),
            .init(id: "level_active", category: .level, label: "Активный", description: "Активный участник.", firstHex: "#4ade80", secondHex: "#16a34a", glyph: nil, text: "10", assetURL: nil, rarity: nil),
            .init(id: "level_advanced", category: .level, label: "Продвинутый", description: "Уверенный пользователь.", firstHex: "#38bdf8", secondHex: "#2563eb", glyph: nil, text: "50", assetURL: nil, rarity: nil),
            .init(id: "level_pro", category: .level, label: "Проф", description: "Профессионал платформы.", firstHex: "#c084fc", secondHex: "#7c3aed", glyph: nil, text: "100", assetURL: nil, rarity: nil),
            .init(id: "level_master", category: .level, label: "Мастер", description: "Мастер своего дела.", firstHex: "#fb923c", secondHex: "#ea580c", glyph: nil, text: "250", assetURL: nil, rarity: nil),
            .init(id: "level_legend", category: .level, label: "Легенда", description: "Легенда сообщества.", firstHex: "#fb7185", secondHex: "#e11d48", glyph: nil, text: "500", assetURL: nil, rarity: nil),

            .init(id: "status_contributor", category: .status, label: "Вклад в Unixgram", description: "За значимый вклад в Unixgram.", firstHex: "#fcd34d", secondHex: "#d97706", glyph: "star", text: nil, assetURL: nil, rarity: nil),
            .init(id: "status_infinite", category: .status, label: "Бесконечный пользователь", description: "Бессрочный статус Unixgram.", firstHex: "#818cf8", secondHex: "#7c3aed", glyph: "infinity", text: nil, assetURL: nil, rarity: nil),
            .init(id: "status_og", category: .status, label: "OG Unixgram", description: "Один из самых первых.", firstHex: "#3a3f4b", secondHex: "#0f1115", glyph: nil, text: "OG", assetURL: nil, rarity: nil)
        ]
        return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }()
}

extension UGPublicProfile {
    var resolvedBadgeIDs: [String] {
        if let badges {
            let ids = badges.compactMap { value in
                switch value {
                case .string(let id):
                    return id
                case .object(let object):
                    if case .string(let id)? = object["id"] { return id }
                    if case .string(let id)? = object["badgeId"] { return id }
                    if case .string(let id)? = object["slug"] { return id }
                    return nil
                default:
                    return nil
                }
            }
            if !ids.isEmpty { return ids }
        }

        // Some Unixgram payloads expose only the user-selected subset. Keep it
        // as a real server fallback rather than manufacturing achievements.
        return selfBadges ?? []
    }
}

struct UnixgramProfileBadgesView: View {
    let ids: [String]
    var size: CGFloat = 28

    private var knownBadges: [UnixgramBadgeDefinition] {
        ids.compactMap { UnixgramBadgeRegistry.all[$0] }
    }

    var body: some View {
        if !knownBadges.isEmpty {
            UnixgramBadgeWrapLayout(spacing: 3) {
                ForEach(knownBadges, id: \.id) { badge in
                    UnixgramBadgeSealView(definition: badge, size: size)
                        .accessibilityLabel(badge.label)
                }
            }
        }
    }
}

private struct UnixgramBadgeWrapLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: min(maxWidth, usedWidth), height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct UnixgramBadgeSealView: View {
    let definition: UnixgramBadgeDefinition
    let size: CGFloat

    var body: some View {
        Group {
            if let asset = definition.assetURL, let url = URL(string: asset) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        sealBody
                    }
                }
            } else {
                sealBody
            }
        }
        .frame(width: size, height: size)
    }

    private var sealBody: some View {
        ZStack {
            UnixgramRosetteShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hexString: definition.firstHex, lightening: 0.50),
                            Color(hexString: definition.secondHex, lightening: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            UnixgramRosetteShape()
                .scale(x: 0.88, y: 0.88, anchor: .center)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hexString: definition.firstHex),
                            Color(hexString: definition.secondHex)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            UnixgramRosetteShape()
                .scale(x: 0.88, y: 0.88, anchor: .center)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            glyph
                .foregroundStyle(.white)
                .frame(width: size * 0.58, height: size * 0.58)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if let text = definition.text {
            Text(text)
                .font(.system(size: size * (text.count <= 1 ? 0.52 : text.count <= 2 ? 0.46 : 0.36), weight: .black, design: .rounded))
                .minimumScaleFactor(0.55)
        } else if definition.glyph == "alien" {
            UnixgramAlienGlyph()
        } else if let symbol = systemSymbol(for: definition.glyph) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .fontWeight((definition.glyph == "heart" || definition.glyph == "star" || definition.glyph == "gem" || definition.glyph == "crown") ? .regular : .bold)
        }
    }

    private func systemSymbol(for glyph: String?) -> String? {
        switch glyph {
        case "check": "checkmark"
        case "music": "music.note"
        case "brush": "paintbrush.fill"
        case "video": "video.fill"
        case "mic": "mic.fill"
        case "cap": "graduationcap.fill"
        case "gamepad": "gamecontroller.fill"
        case "code": "chevron.left.forwardslash.chevron.right"
        case "wind": "wind"
        case "send": "paperplane.fill"
        case "crown": "crown.fill"
        case "gem": "diamond.fill"
        case "heart": "heart.fill"
        case "snowflake": "snowflake"
        case "mask": "theatermasks.fill"
        case "camera": "camera.fill"
        case "leaf": "leaf.fill"
        case "plane": "airplane"
        case "book": "book.closed.fill"
        case "dumbbell": "dumbbell.fill"
        case "chef": "fork.knife"
        case "flask": "testtube.2"
        case "brain": "brain.head.profile"
        case "bitcoin": "bitcoinsign"
        case "star": "star.fill"
        case "infinity": "infinity"
        case "eye": "eye.fill"
        case "moon": "moon.fill"
        case "ghost": "sparkles"
        case "eyeoff": "eye.slash.fill"
        case "flower": "camera.macro"
        case "drama": "theatermasks.fill"
        case "crosshair": "scope"
        case "shieldcheck": "checkmark.shield.fill"
        default: nil
        }
    }
}

private struct UnixgramRosetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points = 240
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let sx = rect.width / 100
        let sy = rect.height / 100
        var path = Path()

        for index in 0...points {
            let angle = Double(index) / Double(points) * Double.pi * 2
            let radius = 42 + 4.5 * cos(10 * angle)
            let point = CGPoint(
                x: center.x + CGFloat(radius * cos(angle)) * sx,
                y: center.y + CGFloat(radius * sin(angle)) * sy
            )
            if index == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct UnixgramAlienGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.50, y: h * 0.08))
                    path.addCurve(
                        to: CGPoint(x: w * 0.19, y: h * 0.38),
                        control1: CGPoint(x: w * 0.31, y: h * 0.08),
                        control2: CGPoint(x: w * 0.19, y: h * 0.20)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.50, y: h * 0.93),
                        control1: CGPoint(x: w * 0.19, y: h * 0.68),
                        control2: CGPoint(x: w * 0.37, y: h * 0.84)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.81, y: h * 0.38),
                        control1: CGPoint(x: w * 0.63, y: h * 0.84),
                        control2: CGPoint(x: w * 0.81, y: h * 0.68)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.50, y: h * 0.08),
                        control1: CGPoint(x: w * 0.81, y: h * 0.20),
                        control2: CGPoint(x: w * 0.69, y: h * 0.08)
                    )
                }
                .fill(.white)

                HStack(spacing: w * 0.16) {
                    Ellipse().fill(Color.black.opacity(0.42))
                    Ellipse().fill(Color.black.opacity(0.42))
                }
                .frame(width: w * 0.55, height: h * 0.20)
                .offset(y: h * 0.05)
            }
        }
    }
}

private extension Color {
    init(hexString: String, lightening: Double = 0) {
        let value = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let number = UInt64(value, radix: 16) ?? 0
        var red = Double((number >> 16) & 0xff) / 255
        var green = Double((number >> 8) & 0xff) / 255
        var blue = Double(number & 0xff) / 255
        if lightening > 0 {
            red += (1 - red) * lightening
            green += (1 - green) * lightening
            blue += (1 - blue) * lightening
        }
        self.init(red: red, green: green, blue: blue)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
