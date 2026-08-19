import SwiftUI

@MainActor
final class SoundCloudNativeStore: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case search = "Поиск"
        case likes = "Лайки"
        case recent = "Недавние"

        var id: String { rawValue }
    }

    @Published var query = ""
    @Published var tracks: [SoundCloudTrack] = []
    @Published var selectedSection: Section = .search
    @Published var isLoading = false
    @Published var playingTrackID: Int?
    @Published var errorMessage: String?
    @Published var playbackError: String?

    private let session = SoundCloudSession.shared

    func loadCurrentSection() async {
        switch selectedSection {
        case .search:
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await search()
            }
        case .likes:
            await loadLikes()
        case .recent:
            await loadRecent()
        }
    }

    func search() async {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            tracks = []
            return
        }

        await perform {
            if self.session.isConnected {
                return try await SoundCloudAPIClient.shared.searchTracks(clean, session: self.session)
            }
            return try await SoundCloudPublicClient.shared.searchTracks(clean)
        }
    }

    func loadLikes() async {
        guard session.isConnected else {
            tracks = []
            errorMessage = "Для своих лайков нужно войти в SoundCloud."
            return
        }
        await perform {
            let result = try await SoundCloudAPIClient.shared.likedTracks(session: self.session)
            UnixgramMusicPlayer.shared.markSoundCloudLikes(Set(result.map(\.id)))
            return result
        }
    }

    func loadRecent() async {
        guard session.isConnected else {
            tracks = []
            errorMessage = "Для истории прослушиваний нужно войти в SoundCloud."
            return
        }
        await perform {
            try await SoundCloudAPIClient.shared.recentlyPlayed(session: self.session)
        }
    }

    func play(_ track: SoundCloudTrack) async {
        guard playingTrackID == nil else { return }
        playbackError = nil
        playingTrackID = track.id
        defer { playingTrackID = nil }

        await UnixgramMusicPlayer.shared.playSoundCloud(track, queue: tracks)
        if let error = UnixgramMusicPlayer.shared.errorMessage {
            playbackError = error
        }
    }

    private func perform(_ operation: @escaping () async throws -> [SoundCloudTrack]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tracks = try await operation()
        } catch {
            tracks = []
            errorMessage = error.localizedDescription
        }
    }
}

struct SoundCloudNativeView: View {
    @StateObject private var session = SoundCloudSession.shared
    @StateObject private var store = SoundCloudNativeStore()
    @ObservedObject private var player = UnixgramMusicPlayer.shared

    @State private var showBrokerSetup = false
    @State private var showNowPlaying = false
    @State private var brokerURLText = SoundCloudConfig.brokerBaseURL?.absoluteString ?? ""

    var body: some View {
        VStack(spacing: 0) {
            header
            sectionPicker
            searchBar

            if store.isLoading {
                ProgressView()
                    .padding(.top, 34)
            } else if let error = store.errorMessage ?? session.errorMessage {
                errorState(error)
            } else if store.tracks.isEmpty {
                emptyState
            } else {
                tracksList
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await session.restoreIfNeeded()
        }
        .sheet(isPresented: $showBrokerSetup) {
            brokerSetupSheet
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            UnixgramNowPlayingView()
        }
        .onChange(of: store.selectedSection) {
            Task { await store.loadCurrentSection() }
        }
        .onChange(of: session.isConnected) {
            if !session.isConnected, store.selectedSection != .search {
                store.selectedSection = .search
                store.tracks = []
            }
        }
        .alert(
            "Не удалось воспроизвести",
            isPresented: Binding(
                get: { store.playbackError != nil },
                set: { if !$0 { store.playbackError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.playbackError ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 1) {
                Text("SoundCloud")
                    .font(.system(size: 24, weight: .bold))
                Text(session.isConnected ? (session.account?.username ?? "Подключено") : "Нативный плеер")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if session.isRestoring || session.isAuthenticating {
                ProgressView()
            } else if session.isConnected {
                Menu {
                    Button("Обновить профиль") {
                        Task { await session.restoreIfNeeded() }
                    }
                    Button("Выйти из SoundCloud", role: .destructive) {
                        Task { await session.disconnect() }
                    }
                } label: {
                    accountAvatar
                }
            } else {
                Button {
                    if SoundCloudConfig.brokerBaseURL == nil {
                        showBrokerSetup = true
                    } else {
                        Task { await session.connect() }
                    }
                } label: {
                    Text("Войти")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.orange.opacity(0.20))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.55)))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(SoundCloudNativeStore.Section.allCases) { section in
                let locked = section != .search && !session.isConnected
                Button {
                    guard !locked else {
                        if SoundCloudConfig.brokerBaseURL == nil {
                            showBrokerSetup = true
                        } else {
                            Task { await session.connect() }
                        }
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.selectedSection = section
                    }
                } label: {
                    HStack(spacing: 5) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                        Text(section.rawValue)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(store.selectedSection == section ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        Capsule().fill(
                            store.selectedSection == section
                                ? Color.orange.opacity(0.18)
                                : Color.clear
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var searchBar: some View {
        if store.selectedSection == .search {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Треки, исполнители", text: $store.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await store.search() }
                    }

                if !store.query.isEmpty {
                    Button {
                        store.query = ""
                        store.tracks = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        } else {
            Color.clear.frame(height: 12)
        }
    }

    private var tracksList: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                ForEach(store.tracks) { track in
                    SoundCloudTrackRow(
                        track: track,
                        isResolving: store.playingTrackID == track.id,
                        isCurrent: player.currentTrack?.id == "soundcloud:\(track.id)",
                        isPlaying: player.currentTrack?.id == "soundcloud:\(track.id)" && player.isPlaying
                    ) {
                        if player.currentTrack?.id == "soundcloud:\(track.id)" {
                            showNowPlaying = true
                        } else {
                            Task { await store.play(track) }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 130)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Spacer()
            Image(systemName: store.selectedSection == .search ? "waveform" : "music.note.list")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)

            Text(emptyTitle)
                .font(.headline)

            Text(emptySubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 42)

            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button("Повторить") {
                session.errorMessage = nil
                Task { await store.loadCurrentSection() }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            Spacer()
        }
    }

    private var emptyTitle: String {
        switch store.selectedSection {
        case .search:
            return store.query.isEmpty ? "Найди музыку" : "Ничего не найдено"
        case .likes:
            return "Нет загруженных лайков"
        case .recent:
            return "Нет недавних треков"
        }
    }

    private var emptySubtitle: String {
        if store.selectedSection == .search {
            return session.isConnected
                ? "Полные треки играют нативно. Ограниченные — через официальный SoundCloud Widget, если сам SoundCloud разрешает воспроизведение."
                : "Без входа используется публичный SoundCloud transport. Аккаунт Unixgram от этого не зависит."
        }
        return "Эта часть доступна после входа в SoundCloud."
    }

    @ViewBuilder
    private var accountAvatar: some View {
        if let raw = session.account?.avatarURL, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle().fill(Color.orange.opacity(0.16))
                        .overlay(Image(systemName: "person.fill"))
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
        }
    }

    private var brokerSetupSheet: some View {
        NavigationStack {
            Form {
                Section("SoundCloud OAuth broker") {
                    TextField("https://…/soundcloud-oauth", text: $brokerURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Text("Client Secret не хранится в приложении. Здесь указывается только HTTPS-адрес твоего server-side broker.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Сохранить") {
                        SoundCloudConfig.setBrokerBaseURL(brokerURLText)
                        showBrokerSetup = false
                        if SoundCloudConfig.brokerBaseURL != nil {
                            Task { await session.connect() }
                        }
                    }
                    .disabled(URL(string: brokerURLText)?.scheme?.lowercased() != "https")
                }
            }
            .navigationTitle("Настройка входа")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { showBrokerSetup = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct SoundCloudTrackRow: View {
    let track: SoundCloudTrack
    let isResolving: Bool
    let isCurrent: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                artwork
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(track.user?.username ?? "SoundCloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        accessBadge
                    }

                    if let count = track.playbackCount, count > 0 {
                        Text("\(compact(count)) прослушиваний")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 8)

                if isResolving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: isCurrent && isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isCurrent ? Color.orange : Color.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(10)
            .background(Color.white.opacity(isCurrent ? 0.065 : 0.035))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCurrent ? Color.orange.opacity(0.25) : Color.white.opacity(0.06))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var accessBadge: some View {
        switch track.access?.lowercased() {
        case "preview":
            Text("WIDGET")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .frame(height: 17)
                .background(Color.orange.opacity(0.12), in: Capsule())
        case "blocked":
            Text("SC")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .frame(height: 17)
                .background(Color.orange.opacity(0.12), in: Capsule())
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let raw = track.artworkURL, let url = URL(string: highResolution(raw)) {
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
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.orange.opacity(0.11))
            .overlay(
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            )
    }

    private func highResolution(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-large.", with: "-t500x500.")
    }

    private func compact(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return String(value)
    }
}
