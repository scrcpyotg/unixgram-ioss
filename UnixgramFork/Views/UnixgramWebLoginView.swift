import SwiftUI
import WebKit

struct UnixgramWebLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var liveSession: UnixgramLiveSession

    var body: some View {
        NavigationStack {
            UnixgramLoginWebView { url in
                guard url.host?.contains("unixgram.com") == true else { return }

                if url.path.hasPrefix("/dashboard") {
                    Task {
                        await UnixgramRealAPIClient.shared.importWebKitCookies()
                        await liveSession.refreshAuthentication()

                        if liveSession.isAuthenticated {
                            dismiss()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Вход в Unixgram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        Task {
                            await UnixgramRealAPIClient.shared.importWebKitCookies()
                            await liveSession.refreshAuthentication()
                            if liveSession.isAuthenticated {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct UnixgramLoginWebView: UIViewRepresentable {
    let onURLChange: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onURLChange: onURLChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        var request = URLRequest(url: URL(string: "https://unixgram.com/auth/login")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onURLChange: (URL) -> Void

        init(onURLChange: @escaping (URL) -> Void) {
            self.onURLChange = onURLChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                onURLChange(url)
            }
        }
    }
}
