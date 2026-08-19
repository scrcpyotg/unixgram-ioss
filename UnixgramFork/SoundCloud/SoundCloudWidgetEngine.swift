import Foundation
import SwiftUI
import WebKit

/// Official SoundCloud HTML5 Widget fallback for tracks that SoundCloud marks as
/// preview/blocked for custom off-platform streams.
///
/// This does not attempt to extract or bypass a restricted stream. Playback remains
/// controlled by SoundCloud's own embedded player and therefore respects whatever
/// access the SoundCloud Widget grants for the current track/region/session.
final class SoundCloudWidgetEngine: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let shared = SoundCloudWidgetEngine()

    enum Event {
        case ready(duration: Double)
        case playing
        case paused
        case progress(position: Double, duration: Double?)
        case finished
        case error(String)
    }

    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var currentURL: URL?
    @Published private(set) var errorMessage: String?

    let webView: WKWebView
    var onEvent: ((Event) -> Void)?

    private var pendingAutoplay = false
    private var pendingSeekSeconds: Double?

    private override init() {
        let controller = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        controller.add(self, name: "unixgramSoundCloud")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "unixgramSoundCloud")
    }

    func load(permalinkURL: URL, autoplay: Bool, seekTo seconds: Double? = nil) {
        currentURL = permalinkURL
        errorMessage = nil
        isReady = false
        isPlaying = false
        position = max(0, seconds ?? 0)
        duration = 0
        pendingAutoplay = autoplay
        pendingSeekSeconds = seconds

        guard var components = URLComponents(string: "https://w.soundcloud.com/player/") else {
            fail("Не удалось создать официальный SoundCloud Widget.")
            return
        }

        components.queryItems = [
            URLQueryItem(name: "url", value: permalinkURL.absoluteString),
            URLQueryItem(name: "auto_play", value: "false"),
            URLQueryItem(name: "buying", value: "false"),
            URLQueryItem(name: "sharing", value: "true"),
            URLQueryItem(name: "download", value: "false"),
            URLQueryItem(name: "show_artwork", value: "false"),
            URLQueryItem(name: "show_comments", value: "false"),
            URLQueryItem(name: "show_playcount", value: "false"),
            URLQueryItem(name: "show_user", value: "true"),
            URLQueryItem(name: "single_active", value: "true"),
            URLQueryItem(name: "color", value: "ff5500")
        ]

        guard let playerURL = components.url else {
            fail("Не удалось создать ссылку SoundCloud Widget.")
            return
        }

        let html = Self.html(playerURL: playerURL)
        webView.loadHTMLString(html, baseURL: URL(string: "https://w.soundcloud.com"))
    }

    func play() {
        evaluate("window.ugWidget && window.ugWidget.play();")
    }

    func pause() {
        evaluate("window.ugWidget && window.ugWidget.pause();")
    }

    func toggle() {
        evaluate("window.ugWidget && window.ugWidget.toggle();")
    }

    func seek(to seconds: Double) {
        let ms = max(0, seconds) * 1000
        evaluate("window.ugWidget && window.ugWidget.seekTo(\(Int(ms)));" )
        position = max(0, seconds)
    }

    func setVolume(_ volume: Double) {
        let value = max(0, min(100, Int(volume.rounded())))
        evaluate("window.ugWidget && window.ugWidget.setVolume(\(value));")
    }

    func reset() {
        pause()
        currentURL = nil
        isReady = false
        isPlaying = false
        position = 0
        duration = 0
        errorMessage = nil
        pendingAutoplay = false
        pendingSeekSeconds = nil
        webView.loadHTMLString("<html><body style='background:transparent'></body></html>", baseURL: nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "unixgramSoundCloud",
              let payload = message.body as? [String: Any],
              let type = payload["type"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch type {
            case "ready":
                let durationMs = Self.number(payload["duration"])
                self.duration = max(0, durationMs / 1000)
                self.isReady = true
                self.onEvent?(.ready(duration: self.duration))

                if let seek = self.pendingSeekSeconds, seek > 0 {
                    self.seek(to: seek)
                }
                self.pendingSeekSeconds = nil

                if self.pendingAutoplay {
                    self.play()
                }
                self.pendingAutoplay = false

            case "play":
                self.isPlaying = true
                self.errorMessage = nil
                self.onEvent?(.playing)

            case "pause":
                self.isPlaying = false
                self.onEvent?(.paused)

            case "progress", "seek":
                let currentMs = Self.number(payload["position"])
                let durationMs = Self.number(payload["duration"])
                self.position = max(0, currentMs / 1000)
                if durationMs > 0 { self.duration = durationMs / 1000 }
                self.onEvent?(.progress(position: self.position, duration: self.duration > 0 ? self.duration : nil))

            case "finish":
                self.isPlaying = false
                self.position = self.duration
                self.onEvent?(.finished)

            case "error":
                let message = (payload["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                self.fail((message?.isEmpty == false ? message : nil) ?? "SoundCloud Widget не смог воспроизвести этот трек.")

            default:
                break
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.fail(error.localizedDescription) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.fail(error.localizedDescription) }
    }

    private func evaluate(_ javaScript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(javaScript, completionHandler: nil)
        }
    }

    private func fail(_ message: String) {
        isReady = false
        isPlaying = false
        errorMessage = message
        onEvent?(.error(message))
    }

    private static func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String, let double = Double(string) { return double }
        return 0
    }

    private static func html(playerURL: URL) -> String {
        let escaped = playerURL.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <style>
            html, body { margin:0; padding:0; width:100%; height:100%; overflow:hidden; background:transparent; }
            iframe { display:block; width:100%; height:100%; border:0; background:transparent; }
          </style>
        </head>
        <body>
          <iframe id="sc-widget" allow="autoplay" scrolling="no" src="\(escaped)"></iframe>
          <script src="https://w.soundcloud.com/player/api.js"></script>
          <script>
            (function() {
              function post(type, data) {
                var payload = data || {};
                payload.type = type;
                try { window.webkit.messageHandlers.unixgramSoundCloud.postMessage(payload); } catch (_) {}
              }

              function durationThen(type, eventData) {
                if (!window.ugWidget) { post(type, eventData || {}); return; }
                window.ugWidget.getDuration(function(d) {
                  var payload = eventData || {};
                  payload.duration = d || 0;
                  post(type, payload);
                });
              }

              var iframe = document.getElementById('sc-widget');
              window.ugWidget = SC.Widget(iframe);

              window.ugWidget.bind(SC.Widget.Events.READY, function() {
                window.ugWidget.getDuration(function(d) { post('ready', { duration: d || 0 }); });
              });
              window.ugWidget.bind(SC.Widget.Events.PLAY, function() { post('play', {}); });
              window.ugWidget.bind(SC.Widget.Events.PAUSE, function() { post('pause', {}); });
              window.ugWidget.bind(SC.Widget.Events.FINISH, function() { post('finish', {}); });
              window.ugWidget.bind(SC.Widget.Events.PLAY_PROGRESS, function(e) {
                durationThen('progress', { position: (e && e.currentPosition) || 0 });
              });
              window.ugWidget.bind(SC.Widget.Events.SEEK, function(e) {
                durationThen('seek', { position: (e && e.currentPosition) || 0 });
              });
              window.ugWidget.bind(SC.Widget.Events.ERROR, function() {
                post('error', { message: 'Официальный SoundCloud Widget не разрешил воспроизведение этого трека.' });
              });
            })();
          </script>
        </body>
        </html>
        """
    }
}

/// Keeps the official widget attached to the view hierarchy while the custom Now Playing
/// UI is on top. Attribution is still shown in the custom player and links back to SoundCloud.
struct SoundCloudWidgetKeepAliveView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear
        attach(to: container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        attach(to: uiView)
    }

    private func attach(to container: UIView) {
        let webView = SoundCloudWidgetEngine.shared.webView
        if webView.superview !== container {
            webView.removeFromSuperview()
            container.addSubview(webView)
            webView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                webView.topAnchor.constraint(equalTo: container.topAnchor),
                webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        }
    }
}
