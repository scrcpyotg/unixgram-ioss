import Foundation
import SwiftUI

struct UnixgramChatAttachment: Identifiable, Hashable {
    enum Kind: Hashable {
        case image
        case video
        case file
    }

    let id: String
    let url: URL
    let kind: Kind
    let name: String?
    let mimeType: String?
    let byteCount: Int?
    let previewURL: URL?
}

enum UnixgramChatContentParser {
    struct ParsedText {
        let text: String?
        let attachment: UnixgramChatAttachment?
    }

    static func textAndInlineAttachment(_ content: String?) -> ParsedText {
        guard let raw = content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            return ParsedText(text: nil, attachment: nil)
        }

        let tokens = raw
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard let last = tokens.last,
              let cleaned = cleanedURLToken(last),
              let url = URL(string: cleaned),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        else {
            return ParsedText(text: raw, attachment: nil)
        }

        let attachment = makeAttachment(
            url: url,
            name: inferredName(from: url),
            mimeType: nil,
            byteCount: nil,
            previewURL: nil
        )

        guard isUnixgramChatMediaURL(url) || attachment.kind != .file else {
            return ParsedText(text: raw, attachment: nil)
        }

        var captionTokens = tokens
        captionTokens.removeLast()
        let caption = captionTokens.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedText(
            text: caption.isEmpty ? nil : caption,
            attachment: attachment
        )
    }

    static func attachments(from value: UGJSONValue?) -> [UnixgramChatAttachment] {
        guard let value else { return [] }

        var result: [UnixgramChatAttachment] = []
        collectAttachments(from: value, into: &result)

        var seen = Set<String>()
        return result.filter { item in
            seen.insert(item.url.absoluteString).inserted
        }
    }

    private static func collectAttachments(
        from value: UGJSONValue,
        into result: inout [UnixgramChatAttachment]
    ) {
        switch value {
        case .string(let raw):
            if let url = URL(string: raw),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                result.append(
                    makeAttachment(
                        url: url,
                        name: inferredName(from: url),
                        mimeType: nil,
                        byteCount: nil,
                        previewURL: nil
                    )
                )
            }

        case .array(let values):
            for child in values {
                collectAttachments(from: child, into: &result)
            }

        case .object(let object):
            let name = object.ugFirstString([
                "fileName", "filename", "name", "title"
            ])
            let mime = object.ugFirstString([
                "mimeType", "mime", "contentType"
            ])
            let byteCount = object.ugFirstInt([
                "size", "bytes", "fileSize", "sizeBytes"
            ])

            let previewRaw = object.ugFirstString([
                "posterUrl", "posterURL", "thumbnailUrl", "thumbnailURL",
                "thumbUrl", "thumbURL", "previewUrl", "previewURL"
            ])
            let preview = previewRaw.flatMap(URL.init(string:))

            let directKeys = [
                "url", "mediaUrl", "mediaURL", "imageUrl", "imageURL",
                "videoUrl", "videoURL", "fileUrl", "fileURL", "downloadUrl"
            ]

            if let raw = object.ugFirstString(directKeys),
               let url = URL(string: raw),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                result.append(
                    makeAttachment(
                        url: url,
                        name: name ?? inferredName(from: url),
                        mimeType: mime,
                        byteCount: byteCount,
                        previewURL: preview
                    )
                )
            }

            let nestedKeys = [
                "attachments", "media", "items", "files", "images", "videos"
            ]
            for key in nestedKeys {
                if let nested = object[key] {
                    collectAttachments(from: nested, into: &result)
                }
            }

        case .number, .bool, .null:
            break
        }
    }

    static func makeAttachment(
        url: URL,
        name: String?,
        mimeType: String?,
        byteCount: Int?,
        previewURL: URL?
    ) -> UnixgramChatAttachment {
        let lowerMIME = mimeType?.lowercased() ?? ""
        let ext = url.pathExtension.lowercased()

        let imageExtensions = Set([
            "jpg", "jpeg", "png", "webp", "gif", "heic", "heif", "bmp"
        ])
        let videoExtensions = Set([
            "mp4", "mov", "m4v", "webm", "avi", "mkv"
        ])

        let kind: UnixgramChatAttachment.Kind
        if lowerMIME.hasPrefix("image/") || imageExtensions.contains(ext) {
            kind = .image
        } else if lowerMIME.hasPrefix("video/") || videoExtensions.contains(ext) {
            kind = .video
        } else {
            kind = .file
        }

        return UnixgramChatAttachment(
            id: url.absoluteString,
            url: url,
            kind: kind,
            name: name,
            mimeType: mimeType,
            byteCount: byteCount,
            previewURL: previewURL
        )
    }

    private static func isUnixgramChatMediaURL(_ url: URL) -> Bool {
        guard url.host?.lowercased().contains("media.unixgram.com") == true else {
            return false
        }
        return url.path.lowercased().contains("/unixgram/chat/")
    }

    private static func inferredName(from url: URL) -> String? {
        let component = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        return component.isEmpty ? nil : component
    }

    private static func cleanedURLToken(_ token: String) -> String? {
        let trimmed = token.trimmingCharacters(
            in: CharacterSet(charactersIn: "[](){}<>.,;!?\"'")
        )
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct UnixgramChatRichMessageContent: View {
    let message: UGMessageDTO
    let outgoing: Bool

    @Environment(\.openURL) private var openURL

    private var parsedText: UnixgramChatContentParser.ParsedText {
        UnixgramChatContentParser.textAndInlineAttachment(message.content)
    }

    private var attachments: [UnixgramChatAttachment] {
        let structured = UnixgramChatContentParser.attachments(from: message.media)
        if !structured.isEmpty { return structured }
        return parsedText.attachment.map { [$0] } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reply = message.replyTo {
                UnixgramChatReplyPreview(value: reply, outgoing: outgoing)
            }

            if let giveaway = message.giveaway {
                UnixgramChatGiveawayCard(value: giveaway)
            }

            if let poll = message.poll {
                UnixgramChatPollCard(value: poll, outgoing: outgoing)
            }

            if shouldRenderLargeEmoji,
               let content = message.content {
                Text(content)
                    .font(.system(size: 54))
                    .lineLimit(1)
                    .padding(.vertical, 2)
            } else if let text = parsedText.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !attachments.isEmpty {
                VStack(spacing: 7) {
                    ForEach(attachments) { attachment in
                        UnixgramChatAttachmentView(
                            attachment: attachment,
                            outgoing: outgoing,
                            onOpen: { openURL(attachment.url) }
                        )
                    }
                }
            }

            if let factCheck = message.factCheck,
               let text = factCheck.ugFirstStringDeep([
                    "text", "content", "label", "verdict"
               ]) {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.yellow)
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                .padding(9)
                .background(Color.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var shouldRenderLargeEmoji: Bool {
        guard message.media == nil,
              message.giveaway == nil,
              message.poll == nil,
              let content = message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty,
              content.count <= 4
        else { return false }

        if message.kind?.lowercased().contains("dice") == true { return true }
        return content.unicodeScalars.allSatisfy { !CharacterSet.alphanumerics.contains($0) }
    }
}

private struct UnixgramChatAttachmentView: View {
    let attachment: UnixgramChatAttachment
    let outgoing: Bool
    let onOpen: () -> Void

    @State private var showImageViewer = false

    var body: some View {
        Group {
            switch attachment.kind {
            case .image:
                imageAttachment
            case .video:
                videoAttachment
            case .file:
                fileAttachment
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            UnixgramChatImageViewer(url: attachment.url)
        }
    }

    private var imageAttachment: some View {
        Button {
            showImageViewer = true
        } label: {
            AsyncImage(url: attachment.url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    mediaPlaceholder(icon: "photo")
                default:
                    ZStack {
                        Color.white.opacity(0.06)
                        ProgressView().tint(.white)
                    }
                }
            }
            .frame(maxWidth: 286)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var videoAttachment: some View {
        Button(action: onOpen) {
            ZStack {
                if let preview = attachment.previewURL {
                    AsyncImage(url: preview) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            mediaPlaceholder(icon: "video.fill")
                        }
                    }
                } else {
                    mediaPlaceholder(icon: "video.fill")
                }

                Circle()
                    .fill(Color.black.opacity(0.62))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }
            }
            .frame(maxWidth: 286)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var fileAttachment: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            outgoing
                            ? Color.white.opacity(0.18)
                            : Color.purple.opacity(0.18)
                        )

                    Image(systemName: fileIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(attachment.name ?? "Файл")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        if let size = attachment.byteCount {
                            Text(ByteCountFormatter.string(
                                fromByteCount: Int64(size),
                                countStyle: .file
                            ))
                        }

                        if let ext = attachment.url.pathExtension.nilIfEmpty {
                            if attachment.byteCount != nil {
                                Text("•")
                            }
                            Text(ext.uppercased())
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(10)
            .background(Color.black.opacity(outgoing ? 0.12 : 0.20))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var fileIcon: String {
        switch attachment.url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "zip", "rar", "7z": return "archivebox"
        case "jar": return "shippingbox"
        case "mp3", "m4a", "wav", "flac": return "waveform"
        default: return "doc.fill"
        }
    }

    @ViewBuilder
    private func mediaPlaceholder(icon: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.09),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

private struct UnixgramChatImageViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1, min(4, value))
                                }
                                .onEnded { value in
                                    scale = max(1, min(4, value))
                                }
                        )
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 42))
                        Text("Не удалось загрузить изображение")
                    }
                    .foregroundStyle(.secondary)
                default:
                    ProgressView().tint(.white)
                }
            }
            .padding(.horizontal, 8)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Color.black.opacity(0.62))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)

                Spacer()
            }
        }
    }
}

private struct UnixgramChatReplyPreview: View {
    let value: UGJSONValue
    let outgoing: Bool

    var body: some View {
        let author = value.ugFirstStringDeep([
            "displayName", "authorName", "senderName", "username"
        ])
        let text = value.ugFirstStringDeep([
            "content", "text", "caption", "message"
        ]) ?? "Сообщение"

        HStack(spacing: 8) {
            Capsule()
                .fill(outgoing ? Color.white.opacity(0.72) : Color.purple)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                if let author, !author.isEmpty {
                    Text(author)
                        .font(.caption.bold())
                        .foregroundStyle(outgoing ? Color.white : Color.purple.opacity(0.92))
                }

                Text(text)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct UnixgramChatGiveawayCard: View {
    let value: UGJSONValue

    private var object: [String: UGJSONValue] {
        value.objectValue ?? [:]
    }

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.68, blue: 0.12),
                                Color(red: 0.93, green: 0.33, blue: 0.48)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 74, height: 74)

                Text("🎁")
                    .font(.system(size: 43))
            }

            Text(object.ugFirstString([
                "title", "name", "headline"
            ]) ?? "Розыгрыш")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 9) {
                giveawayRow(
                    title: "Призы",
                    value: prizeText,
                    icon: "star.fill"
                )
                giveawayRow(
                    title: "Участники",
                    value: participantsText,
                    icon: "person.2.fill"
                )

                if let date = drawDateText {
                    giveawayRow(
                        title: "Дата итогов",
                        value: date,
                        icon: "calendar"
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: 286)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.38, green: 0.20, blue: 0.74).opacity(0.96),
                    Color(red: 0.58, green: 0.26, blue: 0.70).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var prizeText: String {
        if let prizes = object["prizes"]?.arrayValue, !prizes.isEmpty {
            let labels = prizes.compactMap { prize -> String? in
                guard let p = prize.objectValue else {
                    return prize.stringValue
                }

                let count = p.ugFirstInt(["quantity", "count", "winners"]) ?? 1
                if let stars = p.ugFirstInt(["stars", "amount", "value"]) {
                    return "\(count) × ⭐ \(stars)"
                }
                if let title = p.ugFirstString(["title", "name", "label"]) {
                    return "\(count) × \(title)"
                }
                return nil
            }
            if !labels.isEmpty { return labels.joined(separator: "\n") }
        }

        if let stars = object.ugFirstInt(["stars", "amount", "prizeStars"]) {
            let count = object.ugFirstInt(["prizeCount", "winnersCount", "count"]) ?? 1
            return "\(count) × ⭐ \(stars)"
        }

        return object.ugFirstString([
            "prize", "prizeText", "description"
        ]) ?? "Приз Unixgram"
    }

    private var participantsText: String {
        if let count = object.ugFirstInt([
            "participantsCount", "participantCount", "membersCount"
        ]) {
            return "\(count) участников"
        }

        return object.ugFirstString([
            "participants", "audience", "eligibility"
        ]) ?? "Все участники этого чата"
    }

    private var drawDateText: String? {
        guard let raw = object.ugFirstString([
            "endsAt", "endAt", "drawAt", "resultsAt", "finishAt", "date"
        ]) else { return nil }

        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: raw) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return raw
    }

    private func giveawayRow(
        title: String,
        value: String,
        icon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.yellow)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.86))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct UnixgramChatPollCard: View {
    let value: UGJSONValue
    let outgoing: Bool

    private var object: [String: UGJSONValue] {
        value.objectValue ?? [:]
    }

    private var options: [UGJSONValue] {
        object["options"]?.arrayValue
            ?? object["answers"]?.arrayValue
            ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(object.ugFirstString([
                "question", "title", "text"
            ]) ?? "Опрос")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                pollOption(option)
            }

            if let total = object.ugFirstInt([
                "totalVotes", "votesCount", "votersCount"
            ]) {
                Text("\(total) голосов")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(12)
        .background(Color.black.opacity(outgoing ? 0.10 : 0.22))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func pollOption(_ value: UGJSONValue) -> some View {
        let option = value.objectValue ?? [:]
        let text = option.ugFirstString(["text", "label", "title"])
            ?? value.stringValue
            ?? "Вариант"
        let percent = option.ugFirstDouble([
            "percent", "percentage", "ratio"
        ]) ?? 0
        let normalized = percent > 1 ? min(1, percent / 100) : max(0, min(1, percent))

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()

                if normalized > 0 {
                    Text("\(Int((normalized * 100).rounded()))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.66))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(outgoing ? Color.white.opacity(0.74) : Color.purple.opacity(0.82))
                        .frame(width: proxy.size.width * normalized)
                }
            }
            .frame(height: 4)
        }
    }
}

struct UnixgramChatWallpaper: View {
    private let glyphs: [(String, CGFloat, CGFloat, Double)] = [
        ("paperplane", 0.12, 0.12, -0.30),
        ("star", 0.78, 0.10, 0.24),
        ("bubble.left", 0.44, 0.21, -0.15),
        ("gift", 0.90, 0.31, 0.32),
        ("heart", 0.18, 0.39, -0.24),
        ("music.note", 0.60, 0.45, 0.20),
        ("photo", 0.33, 0.58, -0.18),
        ("sparkles", 0.84, 0.62, 0.27),
        ("paperclip", 0.10, 0.72, 0.18),
        ("message", 0.52, 0.79, -0.25),
        ("star.circle", 0.88, 0.88, 0.22),
        ("globe", 0.27, 0.91, -0.16)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.07, blue: 0.30),
                        Color(red: 0.26, green: 0.11, blue: 0.48),
                        Color(red: 0.16, green: 0.06, blue: 0.27)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.30),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: proxy.size.width * 0.9
                )

                ForEach(Array(glyphs.enumerated()), id: \.offset) { _, item in
                    Image(systemName: item.0)
                        .font(.system(size: 27, weight: .regular))
                        .foregroundStyle(.white.opacity(0.055))
                        .rotationEffect(.radians(item.3))
                        .position(
                            x: proxy.size.width * item.1,
                            y: proxy.size.height * item.2
                        )
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension Dictionary where Key == String, Value == UGJSONValue {
    func ugFirstString(_ keys: [String]) -> String? {
        for key in keys {
            if let value = self[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func ugFirstInt(_ keys: [String]) -> Int? {
        for key in keys {
            if let value = self[key]?.intValue {
                return value
            }
        }
        return nil
    }

    func ugFirstDouble(_ keys: [String]) -> Double? {
        for key in keys {
            guard let value = self[key] else { continue }
            switch value {
            case .number(let number):
                return number
            case .string(let raw):
                if let number = Double(raw) { return number }
            default:
                break
            }
        }
        return nil
    }
}

extension UGJSONValue {
    func ugFirstStringDeep(_ keys: [String]) -> String? {
        switch self {
        case .object(let object):
            if let direct = object.ugFirstString(keys) {
                return direct
            }

            for nested in object.values {
                if let value = nested.ugFirstStringDeep(keys) {
                    return value
                }
            }
            return nil

        case .array(let values):
            for value in values {
                if let found = value.ugFirstStringDeep(keys) {
                    return found
                }
            }
            return nil

        default:
            return stringValue
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
