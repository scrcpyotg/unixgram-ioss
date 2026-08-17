import SwiftUI
import WebKit

struct UnixPlaceMarketView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var command: UnixPlaceWebCommand?
    @State private var isLoading = true
    @State private var pageTitle = "Маркет юзов"
    @State private var errorText: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            UnixPlaceWebView(
                command: $command,
                isLoading: $isLoading,
                pageTitle: $pageTitle,
                errorText: $errorText
            )
            .padding(.top, 78)

            topBar

            if isLoading {
                ProgressView()
                    .tint(.purple)
                    .scaleEffect(1.1)
                    .padding(.top, 86)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.black)
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text("Маркет юзов")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                Text(pageTitle == "Маркет юзов" ? "place.unixgram.com" : pageTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button {
                command = .open(URL(string: "https://place.unixgram.com/my")!)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "bag.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Продать")
                        .font(.caption2.bold())
                }
                .foregroundStyle(Color(red: 0.76, green: 0.48, blue: 1.0))
                .frame(width: 58, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.purple.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.purple.opacity(0.50), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.98), Color.black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

enum UnixPlaceWebCommand: Equatable {
    case open(URL)
    case reload
}

private struct UnixPlaceWebView: UIViewRepresentable {
    @Binding var command: UnixPlaceWebCommand?
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var errorText: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLoading: $isLoading,
            pageTitle: $pageTitle,
            errorText: $errorText
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Shared persistent store: same web session container as Unixgram login.
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.contentInset.bottom = 92
        webView.scrollView.verticalScrollIndicatorInsets.bottom = 92

        context.coordinator.webView = webView

        var request = URLRequest(url: URL(string: "https://place.unixgram.com/")!)
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 30
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let command else { return }
        DispatchQueue.main.async {
            switch command {
            case .open(let url):
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                webView.load(request)
            case .reload:
                webView.reload()
            }
            self.command = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        @Binding var pageTitle: String
        @Binding var errorText: String?
        weak var webView: WKWebView?

        init(
            isLoading: Binding<Bool>,
            pageTitle: Binding<String>,
            errorText: Binding<String?>
        ) {
            _isLoading = isLoading
            _pageTitle = pageTitle
            _errorText = errorText
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            errorText = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            errorText = nil

            if let title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                let cleaned = title
                    .replacingOccurrences(of: " · UnixPlace", with: "")
                    .replacingOccurrences(of: " — маркетплейс ников Unixgram", with: "")
                pageTitle = cleaned == "UnixPlace" ? "Маркет юзов" : cleaned
            }
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            isLoading = false
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                errorText = "Не удалось загрузить UnixPlace"
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            isLoading = false
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                errorText = "Не удалось загрузить UnixPlace"
            }
        }

        // Keep target=_blank links inside the in-app market instead of opening Safari.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
