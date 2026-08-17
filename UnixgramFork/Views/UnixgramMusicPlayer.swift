import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit

struct UnixgramMusicTrack: Equatable, Identifiable {
    let id: String
    let title: String
    let artist: String
    let coverURL: URL?
    let streamURL: URL?
    let externalURL: URL?
    let durationMs: Int?
    let provider: String?

    init(
        title: String?,
        artist: String?,
        coverUrl: String?,
        previewUrl: String?,
        externalUrl: String?,
        durationMs: Int?,
        externalId: String?,
        provider: String?
    ) {
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let preview = previewUrl.flatMap(URL.init(string:))
        let external = externalUrl.flatMap(URL.init(string:))

        self.title = cleanTitle.isEmpty ? "Музыка" : cleanTitle
        self.artist = cleanArtist.isEmpty ? (provider ?? "Unixgram") : cleanArtist
        self.coverURL = coverUrl.flatMap(URL.init(string:))
        self.streamURL = preview ?? Self.directAudioURL(from: external)
        self.externalURL = external
        self.durationMs = durationMs
        self.provider = provider
        self.id = previewUrl
            ?? externalId
            ?? externalUrl
            ?? "\(cleanArtist)|\(cleanTitle)|\(provider ?? "")"
    }

    private static func directAudioURL(from url: URL?) -> URL? {
        guard let url else { return nil }
        let ext = url.pathExtension.lowercased()
        let playableExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "caf", "aiff", "m3u8", "mp4"]
        if playableExtensions.contains(ext) { return url }
        if url.host?.contains("media.unixgram.com") == true { return url }
        return nil
    }
}

extension UnixgramMusicTrack {
    init(_ music: UGHARMusic) {
        self.init(
            title: music.title,
            artist: music.artist,
            coverUrl: music.coverUrl,
            previewUrl: music.previewUrl,
            externalUrl: music.externalUrl,
            durationMs: music.durationMs,
            externalId: music.externalId,
            provider: music.provider
        )
    }

    init(_ music: UGProfileMusic) {
        self.init(
            title: music.title,
            artist: music.artist,
            coverUrl: music.coverUrl,
            previewUrl: music.previewUrl,
            externalUrl: music.externalUrl,
            durationMs: music.durationMs,
            externalId: music.externalId,
            provider: music.provider
        )
    }
}

@MainActor
final class UnixgramMusicPlayer: ObservableObject {
    static let shared = UnixgramMusicPlayer()

    @Published private(set) var currentTrack: UnixgramMusicTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var errorMessage: String?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    private init() {
        configureAudioSession()
        installTimeObserver()
        installRemoteCommands()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self,
                      let ended = note.object as? AVPlayerItem,
                      ended === self.player.currentItem else { return }
                self.player.seek(to: .zero)
                self.currentTime = 0
                self.isPlaying = false
                self.updateNowPlaying()
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func isCurrent(_ track: UnixgramMusicTrack) -> Bool {
        currentTrack?.id == track.id
    }

    func toggle(_ track: UnixgramMusicTrack) {
        errorMessage = nil

        if isCurrent(track), player.currentItem != nil {
            isPlaying ? pause() : resume()
            return
        }

        guard let url = track.streamURL else {
            errorMessage = "Unixgram не передал ссылку для встроенного воспроизведения этого трека."
            return
        }

        play(track, url: url)
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard player.currentItem != nil else { return }
        configureAudioSession()
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let bounded = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: bounded, preferredTimescale: 600))
        currentTime = bounded
        updateNowPlaying()
    }

    func close() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentTrack = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        errorMessage = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func showUnavailableMessage() {
        errorMessage = "Для этого трека Unixgram не вернул previewUrl. Можно открыть оригинал в музыкальном сервисе."
    }

    private func play(_ track: UnixgramMusicTrack, url: URL) {
        configureAudioSession()
        isLoading = true
        currentTrack = track
        currentTime = 0
        duration = track.durationMs.map { Double($0) / 1000.0 } ?? 0

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        isLoading = false
        updateNowPlaying()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            errorMessage = "Не удалось включить аудио: \(error.localizedDescription)"
        }
    }

    private func installTimeObserver() {
        let interval = CMTime(seconds: 0.35, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite { self.currentTime = max(0, seconds) }

                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite,
                   itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.updateNowPlaying()
            }
        }
    }

    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying ? self.pause() : self.resume()
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

struct UnixgramMusicRow: View {
    let track: UnixgramMusicTrack
    var compact = false

    @ObservedObject private var player = UnixgramMusicPlayer.shared
    @Environment(\.openURL) private var openURL

    private var active: Bool { player.isCurrent(track) }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: primaryAction) {
                HStack(spacing: compact ? 9 : 12) {
                    cover
                        .frame(width: compact ? 28 : 52, height: compact ? 28 : 52)
                        .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: compact ? 13 : 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if track.streamURL == nil, track.externalURL != nil {
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    } else if track.streamURL == nil {
                        Image(systemName: "speaker.slash.fill")
                            .foregroundStyle(.tertiary)
                    } else if active && player.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: active && player.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundStyle(active ? Color.white : Color.white.opacity(0.85))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if active, player.duration > 0, !compact {
                ProgressView(value: min(player.currentTime, player.duration), total: player.duration)
                    .tint(.white)
                    .scaleEffect(x: 1, y: 0.55, anchor: .center)
                    .padding(.top, 8)
            }
        }
        .padding(compact ? 9 : 12)
        .background(Color.white.opacity(active ? 0.075 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous))
        .overlay {
            if active {
                RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
        .contextMenu {
            if let external = track.externalURL {
                Button("Открыть оригинал", systemImage: "arrow.up.right.square") {
                    openURL(external)
                }
            }
        }

    }

    @ViewBuilder
    private var cover: some View {
        if let url = track.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: compact ? 12 : 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
    }

    private func primaryAction() {
        if track.streamURL != nil {
            player.toggle(track)
        } else if let external = track.externalURL {
            openURL(external)
        } else {
            // Unixgram may return metadata without previewUrl/externalUrl.
            // Keep the row visible, but do not interrupt the profile with an alert.
            return
        }
    }
}

struct UnixgramMiniMusicPlayer: View {
    @ObservedObject private var player = UnixgramMusicPlayer.shared
    @State private var showError = false

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 11) {
                miniCover(track)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    player.isPlaying ? player.pause() : player.resume()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)

                Button {
                    player.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 38)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.96))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            )
            .onChange(of: player.errorMessage) { _, newValue in
                showError = newValue != nil
            }
            .alert("Музыка", isPresented: $showError) {
                Button("OK") { player.errorMessage = nil }
            } message: {
                Text(player.errorMessage ?? "Не удалось воспроизвести трек.")
            }
        }
    }

    @ViewBuilder
    private func miniCover(_ track: UnixgramMusicTrack) -> some View {
        if let url = track.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: miniPlaceholder
                }
            }
        } else {
            miniPlaceholder
        }
    }

    private var miniPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
    }
}
