import SwiftUI
import WebKit

struct UnixgramWebLoginView: View {
    enum Presentation {
        case modal
        case launch
    }

    var presentation: Presentation = .modal

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @State private var isFinishingLogin = false
    @State private var loginError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                UnixgramLoginWebView { url in
                    handle(url)
                }

                if isFinishingLogin {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView("Подключаем аккаунт…")
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Unixgram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if presentation == .modal {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Закрыть") { dismiss() }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Проверить") {
                        finishLogin()
                    }
                    .disabled(isFinishingLogin)
                }
            }
            .alert("Не удалось войти", isPresented: Binding(
                get: { loginError != nil },
                set: { if !$0 { loginError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(loginError ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handle(_ url: URL) {
        guard url.host?.contains("unixgram.com") == true else { return }

        // The official web app enters /dashboard after successful auth.
        if url.path.hasPrefix("/dashboard") {
            finishLogin()
        }
    }

    private func finishLogin() {
        guard !isFinishingLogin else { return }
        isFinishingLogin = true

        Task {
            await UnixgramRealAPIClient.shared.importWebKitCookies()
            await liveSession.refreshAuthentication()

            await MainActor.run {
                isFinishingLogin = false

                if liveSession.isAuthenticated {
                    if presentation == .modal {
                        dismiss()
                    }
                    // In launch mode RootView automatically replaces this view
                    // with MainShellView when launchState becomes .signedIn.
                } else {
                    loginError = liveSession.lastError ?? "Unixgram не создал активную сессию."
                }
            }
        }
    }
}

private struct UnixgramLoginWebView: UIViewRepresentable {
    let onURLChange: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onURLChange: onURLChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Persistent store = the official Unixgram login survives app restarts.
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        var request = URLRequest(url: URL(string: "https://unixgram.com/auth/login")!)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onURLChange: (URL) -> Void

        init(onURLChange: @escaping (URL) -> Void) {
            self.onURLChange = onURLChange
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if let url = webView.url {
                onURLChange(url)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if let url = webView.url {
                onURLChange(url)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                onURLChange(url)
            }
        }
    }
}
