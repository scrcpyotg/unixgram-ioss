import SwiftUI
import WebKit

/// Real Unixgram gift flow inside the iOS client.
///
/// The HARs we have confirm profile gift objects, but do not expose the HTTP
/// catalog/purchase endpoints. To avoid inventing a purchase API, this bridge
/// opens the official Unixgram profile with the same persistent WKWebView
/// cookie store and selects the real Gifts tab. Purchases therefore remain
/// handled by Unixgram itself.
struct UnixgramGiftMarketView: View {
    let username: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var command: UnixgramGiftWebCommand?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            UnixgramGiftWebView(
                username: username,
                command: $command,
                isLoading: $isLoading,
                errorText: $errorText
            )
            .padding(.top, 72)

            topBar

            if isLoading {
                ProgressView()
                    .tint(.purple)
                    .padding(.top, 82)
            }

            if let errorText {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 30))
                    Text(errorText)
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Button("Повторить") {
                        command = .reload
                    }
                    .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(22)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.08), in: Circle())
            }

            VStack(spacing: 2) {
                Text("Маркет подарков")
                    .font(.system(size: 20, weight: .bold))
                Text("Официальный Unixgram")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                command = .reload
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}

private enum UnixgramGiftWebCommand: Equatable {
    case reload
}

private struct UnixgramGiftWebView: UIViewRepresentable {
    let username: String
    @Binding var command: UnixgramGiftWebCommand?
    @Binding var isLoading: Bool
    @Binding var errorText: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorText: $errorText)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        context.coordinator.webView = webView

        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        if let url = URL(string: "https://unixgram.com/u/\(escaped)") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.cachePolicy = .reloadRevalidatingCacheData
            webView.load(request)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let command else { return }
        DispatchQueue.main.async {
            switch command {
            case .reload:
                webView.reload()
            }
            self.command = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        @Binding var errorText: String?
        weak var webView: WKWebView?
        private var didTryOpeningGifts = false

        init(isLoading: Binding<Bool>, errorText: Binding<String?>) {
            _isLoading = isLoading
            _errorText = errorText
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            errorText = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            errorText = nil

            // The public profile's Gifts section is confirmed by the web UI.
            // Select it without depending on unstable CSS class names.
            if !didTryOpeningGifts {
                didTryOpeningGifts = true
                let script = #"""
                (() => {
                  const nodes = Array.from(document.querySelectorAll('button,a,[role="tab"]'));
                  const target = nodes.find((el) => {
                    const t = (el.innerText || el.textContent || '').trim().toLowerCase();
                    return t === 'gifts' || t === 'подарки' || t.includes('gifts');
                  });
                  if (target) { target.click(); return true; }
                  return false;
                })();
                """#
                webView.evaluateJavaScript(script)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        private func handle(_ error: Error) {
            isLoading = false
            let ns = error as NSError
            if ns.code != NSURLErrorCancelled {
                errorText = "Не удалось загрузить подарки Unixgram"
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
