import SwiftUI

struct UnixgramRealAccountView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var showingLogin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let user = liveSession.currentUser {
                    AsyncImage(url: URL(string: user.avatarUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle().fill(Color.white.opacity(0.08))
                        }
                    }
                    .frame(width: 104, height: 104)
                    .clipShape(Circle())

                    Text(user.displayName ?? user.username)
                        .font(.system(size: 28, weight: .bold))

                    Text("@\(user.username)")
                        .foregroundStyle(.secondary)

                    if let location = user.location {
                        Label(location, systemImage: "location")
                            .foregroundStyle(.secondary)
                    }

                    if let website = user.website {
                        Label(website, systemImage: "link")
                            .foregroundStyle(.cyan)
                    }

                    HStack {
                        Label(user.premium == true ? "Premium" : "Обычный аккаунт", systemImage: "sparkles")
                        Spacer()
                        Text(user.language?.uppercased() ?? "")
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button("Обновить данные") {
                        Task { await liveSession.refreshAuthentication() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)

                    Text("Нет активной Unixgram-сессии")
                        .font(.title3.bold())

                    Button("Войти") {
                        showingLogin = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
            .padding(22)
        }
        .background(Color.black)
        .navigationTitle("Реальный аккаунт")
        .sheet(isPresented: $showingLogin) {
            UnixgramWebLoginView()
                .environmentObject(liveSession)
        }
        .task {
            if liveSession.currentUser == nil {
                await liveSession.refreshAuthentication()
            }
        }
    }
}
