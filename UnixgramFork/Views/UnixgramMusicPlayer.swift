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
    let externalId: String?
    let soundCloudTrack: SoundCloudTrack?

    init(
        title: String?,
        artist: String?,
        coverUrl: String?,
        previewUrl: String?,
        externalUrl: String?,
        durationMs: Int?,
        externalId: String?,
        provider: String?,
        soundCloudTrack: SoundCloudTrack? = nil
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
        self.externalId = externalId
        self.soundCloudTrack = soundCloudTrack
        self.id = externalId
            ?? previewUrl
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
    static func soundCloud(_ track: SoundCloudTrack, streamURL: URL? = nil) -> UnixgramMusicTrack {
        UnixgramMusicTrack(
            title: track.title,
            artist: track.user?.username,
            coverUrl: track.artworkURL,
            previewUrl: streamURL?.absoluteString,
            externalUrl: track.permalinkURL,
            durationMs: track.duration,
            externalId: "soundcloud:\(track.id)",
            provider: "SoundCloud",
            soundCloudTrack: track
        )
    }

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
    @Published private(set) var queue: [UnixgramMusicTrack] = []
    @Published private(set) var queueIndex: Int?
    @Published private(set) var likedSoundCloudTrackIDs: Set<Int> = []
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleEnabled = false
    @Published var errorMessage: String?

    enum RepeatMode: String, CaseIterable {
        case off, all, one
    }

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var playerStatusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var failedToEndObserver: NSObjectProtocol?
    private var stalledObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var waitingRecoveryTask: Task<Void, Never>?
    private var isRecovering = false
    private var userWantsPlayback = false
    private var shouldResumeAfterInterruption = false

    private init() {
        // Do not surface an audio-session alert just because the singleton was created.
        // The session is activated again immediately before actual playback.
        _ = configureAudioSession(reportError: false)
        installTimeObserver()
        installPlaybackStateObserver()
        installRemoteCommands()
        installAudioInterruptionObserver()

        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self,
                      let stalled = note.object as? AVPlayerItem,
                      stalled === self.player.currentItem,
                      self.userWantsPlayback else { return }
                self.scheduleRecoveryIfStillStalled()
            }
        }

        failedToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self,
                      let failed = note.object as? AVPlayerItem,
                      failed === self.player.currentItem else { return }

                self.isPlaying = false
                self.isLoading = true
                if self.currentTrack?.soundCloudTrack != nil, self.userWantsPlayback {
                    await self.recoverCurrentSoundCloudStream(reason: "failed-to-end")
                } else {
                    self.isLoading = false
                    let underlying = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error) ?? failed.error
                    self.errorMessage = underlying.map { "Не удалось воспроизвести поток: \($0.localizedDescription)" }
                        ?? "Не удалось воспроизвести аудиопоток."
                    self.updateNowPlaying()
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self,
                      let ended = note.object as? AVPlayerItem,
                      ended === self.player.currentItem else { return }
                self.currentTime = 0
                if self.repeatMode == .one {
                    await self.player.seek(to: .zero)
                    self.userWantsPlayback = true
                    self.player.playImmediately(atRate: 1.0)
                } else if self.canGoNext || self.repeatMode == .all {
                    await self.next()
                } else {
                    await self.player.seek(to: .zero)
                    self.userWantsPlayback = false
                    self.isPlaying = false
                    self.updateNowPlaying()
                }
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failedToEndObserver { NotificationCenter.default.removeObserver(failedToEndObserver) }
        if let stalledObserver { NotificationCenter.default.removeObserver(stalledObserver) }
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        waitingRecoveryTask?.cancel()
    }

    func isCurrent(_ track: UnixgramMusicTrack) -> Bool {
        currentTrack?.id == track.id
    }

    var canGoNext: Bool {
        guard !queue.isEmpty, let queueIndex else { return false }
        return queueIndex + 1 < queue.count
    }

    var canGoPrevious: Bool {
        guard !queue.isEmpty, let queueIndex else { return false }
        return queueIndex > 0
    }

    var currentSoundCloudTrack: SoundCloudTrack? { currentTrack?.soundCloudTrack }

    func markSoundCloudLikes(_ ids: Set<Int>) {
        likedSoundCloudTrackIDs.formUnion(ids)
    }

    func isLiked(_ track: SoundCloudTrack) -> Bool {
        likedSoundCloudTrackIDs.contains(track.id)
    }

    func toggleLikeCurrent() async {
        guard let track = currentTrack?.soundCloudTrack,
              SoundCloudSession.shared.isConnected else { return }
        do {
            if likedSoundCloudTrackIDs.contains(track.id) {
                try await SoundCloudAPIClient.shared.unlike(track: track, session: SoundCloudSession.shared)
                likedSoundCloudTrackIDs.remove(track.id)
            } else {
                try await SoundCloudAPIClient.shared.like(track: track, session: SoundCloudSession.shared)
                likedSoundCloudTrackIDs.insert(track.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playSoundCloud(_ track: SoundCloudTrack, queue source: [SoundCloudTrack]) async {
        let mapped = source.map { UnixgramMusicTrack.soundCloud($0) }
        queue = mapped
        queueIndex = mapped.firstIndex(where: { $0.id == "soundcloud:\(track.id)" })
            ?? 0
        await playQueueItem(at: queueIndex ?? 0, resumeAt: nil)
    }

    func next() async {
        guard !queue.isEmpty else { return }
        var target: Int
        if shuffleEnabled, queue.count > 1 {
            let current = queueIndex ?? 0
            repeat { target = Int.random(in: 0..<queue.count) } while target == current
        } else if let index = queueIndex, index + 1 < queue.count {
            target = index + 1
        } else if repeatMode == .all {
            target = 0
        } else {
            return
        }
        queueIndex = target
        await playQueueItem(at: target, resumeAt: nil)
    }

    func previous() async {
        if currentTime > 4 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        let target: Int
        if let index = queueIndex, index > 0 {
            target = index - 1
        } else if repeatMode == .all {
            target = max(0, queue.count - 1)
        } else {
            seek(to: 0)
            return
        }
        queueIndex = target
        await playQueueItem(at: target, resumeAt: nil)
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func toggleShuffle() { shuffleEnabled.toggle() }

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

        queue = [track]
        queueIndex = 0
        userWantsPlayback = true
        Task { await prepareAndPlay(track, url: url, resumeAt: nil) }
    }

    func pause() {
        userWantsPlayback = false
        waitingRecoveryTask?.cancel()
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        userWantsPlayback = true
        guard player.currentItem != nil else {
            if let index = queueIndex { Task { await playQueueItem(at: index, resumeAt: currentTime) } }
            return
        }
        guard configureAudioSession() else {
            isPlaying = false
            return
        }
        player.isMuted = false
        player.volume = 1.0
        player.playImmediately(atRate: 1.0)
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
        userWantsPlayback = false
        waitingRecoveryTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentTrack = nil
        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        errorMessage = nil
        queue = []
        queueIndex = nil
        itemStatusObservation = nil
        let nowPlaying = MPNowPlayingInfoCenter.default()
        nowPlaying.nowPlayingInfo = nil
        nowPlaying.playbackState = .stopped

        // Let other audio apps regain their session when Unixgram closes the player.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func showUnavailableMessage() {
        errorMessage = "Для этого трека Unixgram не вернул previewUrl. Можно открыть оригинал в музыкальном сервисе."
    }

    private func prepareAndPlay(_ track: UnixgramMusicTrack, url: URL, resumeAt: Double?) async {
        guard configureAudioSession() else {
            isPlaying = false
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        currentTrack = track
        currentTime = max(0, resumeAt ?? 0)
        duration = track.durationMs.map { Double($0) / 1000.0 } ?? 0

        let asset = AVURLAsset(url: url)

        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard !audioTracks.isEmpty else {
                isLoading = false
                isPlaying = false
                errorMessage = "SoundCloud вернул поток без доступной аудиодорожки."
                return
            }
        } catch {
            isLoading = false
            isPlaying = false
            errorMessage = "Не удалось подготовить SoundCloud-аудио: \(error.localizedDescription)"
            return
        }

        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2.0

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] observed, _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, item === self.player.currentItem else { return }
                switch observed.status {
                case .readyToPlay:
                    self.player.isMuted = false
                    self.player.volume = 1.0
                    if let resumeAt, resumeAt > 0 {
                        let target = CMTime(seconds: resumeAt, preferredTimescale: 600)
                        self.player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                            Task { @MainActor [weak self] in
                                guard let self, self.userWantsPlayback else { return }
                                self.player.playImmediately(atRate: 1.0)
                            }
                        }
                    } else if self.userWantsPlayback {
                        self.player.playImmediately(atRate: 1.0)
                    }
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    self.errorMessage = observed.error.map {
                        "Не удалось воспроизвести SoundCloud: \($0.localizedDescription)"
                    } ?? "Не удалось воспроизвести SoundCloud-поток."
                    self.updateNowPlaying()
                case .unknown:
                    self.isLoading = true
                @unknown default:
                    break
                }
            }
        }

        player.pause()
        player.replaceCurrentItem(with: item)
        player.isMuted = false
        player.volume = 1.0
        updateNowPlaying()
    }

    private func playQueueItem(at index: Int, resumeAt: Double?) async {
        guard queue.indices.contains(index) else { return }
        var track = queue[index]
        userWantsPlayback = true
        isLoading = true
        errorMessage = nil

        do {
            if let sc = track.soundCloudTrack {
                let streamURL: URL
                if SoundCloudSession.shared.isConnected {
                    streamURL = try await SoundCloudAPIClient.shared.streamURL(for: sc, session: SoundCloudSession.shared)
                } else {
                    streamURL = try await SoundCloudPublicClient.shared.streamURL(for: sc)
                }
                track = UnixgramMusicTrack.soundCloud(sc, streamURL: streamURL)
                queue[index] = track
            }
            guard let url = track.streamURL else {
                throw NSError(domain: "UnixgramMusic", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет доступного аудиопотока."])
            }
            queueIndex = index
            await prepareAndPlay(track, url: url, resumeAt: resumeAt)
        } catch {
            isLoading = false
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleRecoveryIfStillStalled() {
        waitingRecoveryTask?.cancel()
        waitingRecoveryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.userWantsPlayback,
                      self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate else { return }
                Task { await self.recoverCurrentSoundCloudStream(reason: "stalled") }
            }
        }
    }

    private func recoverCurrentSoundCloudStream(reason: String) async {
        guard !isRecovering, userWantsPlayback,
              let index = queueIndex, queue.indices.contains(index),
              queue[index].soundCloudTrack != nil else { return }
        isRecovering = true
        defer { isRecovering = false }
        let resumePoint = currentTime
        await playQueueItem(at: index, resumeAt: resumePoint)
    }

    private func installAudioInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
                switch type {
                case .began:
                    self.shouldResumeAfterInterruption = self.userWantsPlayback
                    self.isPlaying = false
                case .ended:
                    let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                    if self.shouldResumeAfterInterruption && options.contains(.shouldResume) {
                        self.userWantsPlayback = true
                        self.resume()
                    }
                    self.shouldResumeAfterInterruption = false
                @unknown default:
                    break
                }
            }
        }
    }

    @discardableResult
    private func configureAudioSession(reportError: Bool = true) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()

            // `.playback` already enables normal output routing, including AirPlay and
            // Bluetooth A2DP where available. Explicit `.allowAirPlay` is only valid
            // when using `.playAndRecord`, and passing it with `.playback` can produce
            // OSStatus -50 (invalid parameter) on iOS.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            return true
        } catch {
            if reportError {
                errorMessage = "Не удалось включить аудио: \(error.localizedDescription)"
            }
            return false
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

    private func installPlaybackStateObserver() {
        playerStatusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observed, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch observed.timeControlStatus {
                case .playing:
                    self.waitingRecoveryTask?.cancel()
                    self.isPlaying = true
                    self.isLoading = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isPlaying = false
                    self.isLoading = self.currentTrack != nil
                    if self.userWantsPlayback, self.currentTrack?.soundCloudTrack != nil {
                        self.scheduleRecoveryIfStillStalled()
                    }
                case .paused:
                    self.isPlaying = false
                    if observed.currentItem?.status == .readyToPlay {
                        self.isLoading = false
                    }
                @unknown default:
                    self.isPlaying = false
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
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true

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
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in await self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in await self?.previous() }
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
            MPNowPlayingInfoPropertyExternalContentIdentifier: track.externalId ?? track.id,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused
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
        RoundedRectangle(cornerRadius: compact ? 8 : 10)
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
    @State private var showNowPlaying = false

    var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: 11) {
                Button {
                    showNowPlaying = true
                } label: {
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
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 6)

                Button {
                    player.isPlaying ? player.pause() : player.resume()
                } label: {
                    Group {
                        if player.isLoading { ProgressView().controlSize(.small) }
                        else { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill") }
                    }
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
            .onChange(of: player.errorMessage) { _, newValue in showError = newValue != nil }
            .alert("Музыка", isPresented: $showError) {
                Button("OK") { player.errorMessage = nil }
            } message: {
                Text(player.errorMessage ?? "Не удалось воспроизвести трек.")
            }
            .fullScreenCover(isPresented: $showNowPlaying) {
                UnixgramNowPlayingView()
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
        } else { miniPlaceholder }
    }

    private var miniPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.08))
            .overlay { Image(systemName: "music.note").foregroundStyle(.secondary) }
    }
}

struct UnixgramNowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = UnixgramMusicPlayer.shared
    @State private var sliderValue: Double = 0
    @State private var isScrubbing = false
    @State private var showQueue = false
    @State private var showError = false

    private var track: UnixgramMusicTrack? { player.currentTrack }
    private var currentSC: SoundCloudTrack? { player.currentSoundCloudTrack }

    var body: some View {
        ZStack {
            background
            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.72), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let track {
                VStack(spacing: 0) {
                    topBar(track)
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                    Spacer(minLength: 20)

                    artwork(track)
                        .frame(maxWidth: 310, maxHeight: 310)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(.horizontal, 34)
                        .shadow(color: .black.opacity(0.42), radius: 26, y: 16)

                    Spacer(minLength: 30)

                    VStack(spacing: 22) {
                        titleBlock(track)
                        progressBlock
                        transportControls
                        secondaryControls(track)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { sliderValue = player.currentTime }
        .onChange(of: player.currentTime) { _, value in
            if !isScrubbing { sliderValue = value }
        }
        .onChange(of: player.errorMessage) { _, value in showError = value != nil }
        .alert("Музыка", isPresented: $showError) {
            Button("OK") { player.errorMessage = nil }
        } message: {
            Text(player.errorMessage ?? "Не удалось воспроизвести трек.")
        }
        .sheet(isPresented: $showQueue) {
            UnixgramMusicQueueView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let url = track?.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill().blur(radius: 55).scaleEffect(1.25).opacity(0.42)
                default: Color.black
                }
            }
            .ignoresSafeArea()
        } else { Color.black.ignoresSafeArea() }
    }

    private func topBar(_ track: UnixgramMusicTrack) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("СЕЙЧАС ИГРАЕТ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.7)
                    .foregroundStyle(.secondary)
                Text(track.provider == "SoundCloud" ? "SoundCloud" : "Unixgram Music")
                    .font(.system(size: 12, weight: .semibold))
            }

            Spacer()

            Menu {
                if let url = track.externalURL { ShareLink(item: url) { Label("Поделиться", systemImage: "square.and.arrow.up") } }
                Button("Очередь", systemImage: "list.bullet") { showQueue = true }
                Button("Закрыть плеер", systemImage: "xmark", role: .destructive) { player.close(); dismiss() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    @ViewBuilder
    private func artwork(_ track: UnixgramMusicTrack) -> some View {
        if let url = track.coverURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: artworkPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else { artworkPlaceholder }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay { Image(systemName: "waveform").font(.system(size: 56)).foregroundStyle(.secondary) }
    }

    private func titleBlock(_ track: UnixgramMusicTrack) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)
                Text(track.artist)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            if let sc = currentSC, SoundCloudSession.shared.isConnected {
                Button {
                    Task { await player.toggleLikeCurrent() }
                } label: {
                    Image(systemName: player.isLiked(sc) ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(player.isLiked(sc) ? Color.orange : Color.white.opacity(0.78))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressBlock: some View {
        VStack(spacing: 6) {
            Slider(
                value: $sliderValue,
                in: 0...max(1, player.duration),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing { player.seek(to: sliderValue) }
                }
            )
            .tint(.white)

            HStack {
                Text(formatTime(sliderValue))
                Spacer()
                Text(player.duration > 0 ? "-\(formatTime(max(0, player.duration - sliderValue)))" : "--:--")
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var transportControls: some View {
        HStack {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(player.shuffleEnabled ? Color.orange : Color.white.opacity(0.62))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button { Task { await player.previous() } } label: {
                Image(systemName: "backward.end.fill").font(.system(size: 27, weight: .semibold))
            }
            .disabled(!player.canGoPrevious && player.currentTime <= 4)

            Spacer()

            Button {
                player.isPlaying ? player.pause() : player.resume()
            } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 76, height: 76)
                    if player.isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 29, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button { Task { await player.next() } } label: {
                Image(systemName: "forward.end.fill").font(.system(size: 27, weight: .semibold))
            }
            .disabled(!player.canGoNext && player.repeatMode != .all)

            Spacer()

            Button { player.cycleRepeatMode() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(player.repeatMode == .off ? Color.white.opacity(0.62) : Color.orange)
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
    }

    private func secondaryControls(_ track: UnixgramMusicTrack) -> some View {
        HStack(spacing: 14) {
            Label(track.provider ?? "UNIXGRAM MUSIC", systemImage: "music.note")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.25)
                .foregroundStyle(.secondary)

            Spacer()

            if let url = track.externalURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            Button { showQueue = true } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let value = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct UnixgramMusicQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = UnixgramMusicPlayer.shared

    var body: some View {
        NavigationStack {
            List(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                Button {
                    Task {
                        if index > (player.queueIndex ?? 0) {
                            while (player.queueIndex ?? 0) < index { await player.next() }
                        } else if index < (player.queueIndex ?? 0) {
                            while (player.queueIndex ?? 0) > index { await player.previous() }
                        }
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let url = track.coverURL {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase { image.resizable().scaledToFill() }
                                else { Color.white.opacity(0.06) }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        VStack(alignment: .leading) {
                            Text(track.title).foregroundStyle(.primary).lineLimit(1)
                            Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if index == player.queueIndex { Image(systemName: "waveform").foregroundStyle(.orange) }
                    }
                }
            }
            .navigationTitle("Очередь")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }
    }
}
