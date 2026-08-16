import SwiftUI

struct UnixgramLaunchAuthView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var showOfficialLogin = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 18) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.18, green: 0.68, blue: 0.72),
                                         Color(red: 0.32, green: 0.92, blue: 0.67)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 96, height: 96)
                        .overlay {
                            Image(systemName: "scribble.variable")
                                .font(.system(size: 44, weight: .medium))
                                .foregroundStyle(.white)
                        }

                    Text("Unixgram")
                        .font(.system(size: 38, weight: .bold))

                    Text("Войдите в настоящий аккаунт Unixgram")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Авторизация проходит на официальной странице Unixgram. Пароль не сохраняется в iOS-клиенте.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showOfficialLogin = true
                    } label: {
                        Text("Войти в Unixgram")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Button {
                        Task { await liveSession.refreshAuthentication() }
                    } label: {
                        Text("У меня уже есть активная сессия")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }

                    if let error = liveSession.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
        .fullScreenCover(isPresented: $showOfficialLogin) {
            UnixgramWebLoginView(presentation: .launch)
                .environmentObject(liveSession)
        }
        .onChange(of: liveSession.isAuthenticated) {
            if liveSession.isAuthenticated {
                showOfficialLogin = false
            }
        }
    }
}

struct UnixgramLaunchCheckingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                    .overlay {
                        Image(systemName: "scribble.variable")
                            .font(.system(size: 38))
                            .foregroundStyle(.white)
                    }

                ProgressView()
                    .tint(.white)

                Text("Проверяем сессию Unixgram…")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
