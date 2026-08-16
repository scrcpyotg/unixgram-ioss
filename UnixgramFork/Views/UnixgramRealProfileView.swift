import SwiftUI

struct UnixgramRealProfileView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var showSettings = false

    var body: some View {
        Group {
            if let user = liveSession.currentUser {
                profile(user)
            } else {
                ProgressView("Загружаем профиль…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .task {
            if liveSession.currentUser == nil {
                await liveSession.refreshAuthentication()
            }
        }
        .sheet(isPresented: $showSettings) {
            if let user = liveSession.currentUser {
                UnixgramRealProfileSettingsSheet(
                    isPresented: $showSettings,
                    user: user
                )
                .environmentObject(liveSession)
                .presentationDetents([.fraction(0.82), .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
                .presentationBackground(.clear)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func profile(_ user: UGCurrentAccount) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    profileCover(user)
                        .frame(height: 300)
                        .clipped()

                    HStack {
                        circleButton("chevron.left")
                        Spacer()
                        if user.premium == true {
                            circleButton("sparkles")
                        }
                        circleButton("qrcode")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        ZStack(alignment: .bottomTrailing) {
                            avatar(user)
                                .frame(width: 122, height: 122)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.black, lineWidth: 4))

                            Circle()
                                .fill(.green)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(.black, lineWidth: 4))
                        }

                        Spacer()

                        Button("Редактировать") {
                            showSettings = true
                        }
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 22)
                        .frame(height: 50)
                        .background(Color.black)
                        .overlay(Capsule().stroke(Color.white.opacity(0.14)))
                        .clipShape(Capsule())

                        circleButton("sparkles")
                        circleButton("gift")
                    }
                    .offset(y: -58)
                    .padding(.bottom, -58)

                    HStack(spacing: 8) {
                        Text(user.displayName ?? user.username)
                            .font(.system(size: 27, weight: .bold))

                        if let badge = user.verificationBadge,
                           badge != "NONE" {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.cyan)
                        }

                        if let n = user.registrationNumber {
                            Text("◉ \(n)")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(UGTheme.surface2)
                                .clipShape(Capsule())
                        }
                    }

                    Text("@\(user.username)")
                        .font(.system(size: 21))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Circle().fill(.green).frame(width: 10, height: 10)
                        Text("В сети").foregroundStyle(.green)
                    }
                    .font(.system(size: 19))

                    if let aliases = user.usernameAliases, !aliases.isEmpty {
                        Text("а также ")
                            .foregroundStyle(.white)
                        + Text(aliases.map { "@\($0)" }.joined(separator: ", "))
                            .foregroundStyle(UGTheme.blue)
                    }

                    if user.premium == true {
                        HStack(spacing: 12) {
                            badgeGlyph("◆", tint: .purple)
                            badgeGlyph("✦", tint: .cyan)
                        }
                        .padding(.vertical, 4)
                    }

                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 18))
                    }

                    if let location = user.location, !location.isEmpty {
                        metadata("location", location)
                    }

                    if let website = user.website, !website.isEmpty {
                        metadata("link", cleanedWebsite(website))
                    }

                    if let created = user.createdAt {
                        metadata("calendar", "На Unixgram с \(friendlyDate(created))")
                    }

                    if let email = user.email {
                        metadata("envelope", email)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: user.premium == true ? "sparkles" : "person.crop.circle")
                        Text(user.premium == true ? "Unix Premium" : "Обычный аккаунт")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Text(user.language?.uppercased() ?? "")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(UGTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        showSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Настройки профиля")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .background(UGTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.black)
        .refreshable {
            await liveSession.refreshAuthentication()
        }
    }

    @ViewBuilder
    private func profileCover(_ user: UGCurrentAccount) -> some View {
        if let raw = user.coverUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    coverFallback
                }
            }
        } else {
            coverFallback
        }
    }

    private var coverFallback: some View {
        LinearGradient(
            colors: [Color.brown.opacity(0.5), Color.gray.opacity(0.18), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func avatar(_ user: UGCurrentAccount) -> some View {
        if let raw = user.avatarUrl, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarFallback(user)
                }
            }
        } else {
            avatarFallback(user)
        }
    }

    private func avatarFallback(_ user: UGCurrentAccount) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(String((user.displayName ?? user.username).prefix(1)).uppercased())
                    .font(.system(size: 46, weight: .bold))
            }
    }

    private func circleButton(_ icon: String) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.62))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12)))
        }
    }

    private func badgeGlyph(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(tint.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metadata(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(title).foregroundStyle(.secondary)
        }
        .font(.system(size: 18))
    }

    private func cleanedWebsite(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private func friendlyDate(_ raw: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
