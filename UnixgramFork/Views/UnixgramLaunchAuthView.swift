import SwiftUI

private struct UnixgramBrandLogo: View {
    let size: CGFloat

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .contentShape(Circle())
    }
}

struct UnixgramLaunchAuthView: View {
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var showOfficialLogin = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 18) {
                    UnixgramBrandLogo(size: 104)

                    Text("Unixgram")
                        .font(.system(size: 38, weight: .bold))
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
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                UnixgramBrandLogo(size: 94)

                ProgressView()
                    .tint(.white)

                Text(liveSession.lastError == nil ? "Проверяем сессию Unixgram…" : "Нет соединения. Сессия не сброшена")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                if liveSession.lastError != nil {
                    Button("Повторить") {
                        Task { await liveSession.refreshAuthentication(showCheckingState: true) }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
        }
    }
}
