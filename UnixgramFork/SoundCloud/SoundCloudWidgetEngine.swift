import Foundation
import SwiftUI
import WebKit
import UIKit

/// Persistent SoundCloud web-player bridge.
///
/// Playback stays inside the real `soundcloud.com` web player using the user's
/// own WebKit session. Unixgram only sends normal media controls (play/pause/seek)
/// and reads playback state from HTML media events. It never extracts CDN/media URLs.
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
    @Published private(set) var currentPageURL: URL?
    @Published private(set) var isLoginPage = false
    @Published private(set) var likelySignedIn = false
    @Published private(set) var errorMessage: String?

    let webView: WKWebView
    var onEvent: ((Event) -> Void)?

    private var pendingAutoplay = false
    private var pendingSeekSeconds: Double?
    private var pendingTrackURL: URL?
    private var retryWorkItems: [DispatchWorkItem] = []

    private override init() {
        let controller = WKUserContentController()
        controller.addUserScript(
            WKUserScript(
                source: Self.bridgeJavaScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .default() // persistent login/cookies between launches
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        controller.add(self, name: "unixgramSoundCloudWeb")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = true

        refreshCookieSessionState()
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "unixgramSoundCloudWeb")
    }

    func load(permalinkURL: URL, autoplay: Bool, seekTo seconds: Double? = nil) {
        cancelRetries()
        currentURL = permalinkURL
        pendingTrackURL = permalinkURL
        pendingAutoplay = autoplay
        pendingSeekSeconds = seconds
        errorMessage = nil
        isReady = false
        isPlaying = false
        position = max(0, seconds ?? 0)
        duration = 0

        var request = URLRequest(url: permalinkURL)
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 30
        webView.load(request)
    }

    func play() {
        pendingAutoplay = true
        evaluate(Self.playCommand)
        schedulePlaybackRetries()
    }

    func pause() {
        pendingAutoplay = false
        cancelRetries()
        evaluate(Self.pauseCommand)
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        let bounded = max(0, seconds)
        position = bounded
        pendingSeekSeconds = bounded
        evaluate("window.__unixgramSCWeb && window.__unixgramSCWeb.seek(\(bounded));")
    }

    func setVolume(_ volume: Double) {
        let normalized = max(0, min(1, volume / 100.0))
        evaluate("window.__unixgramSCWeb && window.__unixgramSCWeb.setVolume(\(normalized));")
    }

    /// Opens the real SoundCloud sign-in page in the same persistent WKWebView.
    /// Closing the sheet returns to the previously requested track.
    func openSignIn() {
        cancelRetries()
        guard let url = URL(string: "https://soundcloud.com/signin") else { return }
        webView.load(URLRequest(url: url))
    }

    func openSoundCloudHome() {
        cancelRetries()
        guard let url = URL(string: "https://soundcloud.com/") else { return }
        webView.load(URLRequest(url: url))
    }

    func resumePendingTrack(autoplay: Bool? = nil) {
        guard let url = pendingTrackURL else { return }
        load(
            permalinkURL: url,
            autoplay: autoplay ?? pendingAutoplay,
            seekTo: position > 0 ? position : pendingSeekSeconds
        )
    }

    func refreshSessionState() {
        refreshCookieSessionState()
        evaluate(Self.sessionProbeCommand)
    }

    func reset() {
        pause()
        currentURL = nil
        pendingTrackURL = nil
        isReady = false
        isPlaying = false
        position = 0
        duration = 0
        errorMessage = nil
        pendingSeekSeconds = nil
        webView.loadHTMLString("<html><body style='background:#000'></body></html>", baseURL: nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "unixgramSoundCloudWeb",
              let payload = message.body as? [String: Any],
              let type = payload["type"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case "bridgeReady":
                self.isReady = true
                self.refreshCookieSessionState()
                if self.pendingAutoplay { self.schedulePlaybackRetries() }

            case "ready":
                let value = Self.number(payload["duration"])
                if value.isFinite, value > 0 { self.duration = value }
                self.isReady = true
                self.onEvent?(.ready(duration: self.duration))

                if let seek = self.pendingSeekSeconds, seek > 0 {
                    self.seek(to: seek)
                }
                self.pendingSeekSeconds = nil
                if self.pendingAutoplay { self.play() }

            case "play":
                self.cancelRetries()
                self.isPlaying = true
                self.isReady = true
                self.errorMessage = nil
                self.onEvent?(.playing)

            case "pause":
                self.isPlaying = false
                self.onEvent?(.paused)

            case "progress":
                let current = Self.number(payload["position"])
                let total = Self.number(payload["duration"])
                if current.isFinite { self.position = max(0, current) }
                if total.isFinite, total > 0 { self.duration = total }
                self.onEvent?(.progress(position: self.position, duration: self.duration > 0 ? self.duration : nil))

            case "finish":
                self.cancelRetries()
                self.isPlaying = false
                self.position = self.duration
                self.onEvent?(.finished)

            case "loginState":
                if let signedIn = payload["signedIn"] as? Bool {
                    self.likelySignedIn = signedIn || self.likelySignedIn
                }

            case "loginRequired":
                self.cancelRetries()
                self.isPlaying = false
                self.fail("Для полного воспроизведения войди в SoundCloud Web Player внутри Unixgram.")

            case "error":
                let text = (payload["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                self.fail((text?.isEmpty == false ? text : nil) ?? "Веб-плеер SoundCloud не смог запустить этот трек.")

            default:
                break
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        currentPageURL = webView.url
        let path = webView.url?.path.lowercased() ?? ""
        isLoginPage = path.contains("signin") || path.contains("login") || path.contains("connect")
        refreshCookieSessionState()
        evaluate(Self.sessionProbeCommand)

        // User tapped Play in Unixgram, so retry normal site play controls while the
        // SPA finishes hydrating. No media URL is inspected or extracted.
        if pendingAutoplay && !isLoginPage {
            schedulePlaybackRetries()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.fail(error.localizedDescription) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.fail(error.localizedDescription) }
    }

    private func schedulePlaybackRetries() {
        cancelRetries()
        let delays: [Double] = [0.15, 0.75, 1.6, 3.0, 5.0]
        for delay in delays {
            let item = DispatchWorkItem { [weak self] in
                guard let self, self.pendingAutoplay, !self.isPlaying else { return }
                self.evaluate(Self.playCommand)
                self.evaluate(Self.sessionProbeCommand)
            }
            retryWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func cancelRetries() {
        retryWorkItems.forEach { $0.cancel() }
        retryWorkItems.removeAll()
    }

    private func evaluate(_ javaScript: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(javaScript, completionHandler: nil)
        }
    }

    private func refreshCookieSessionState() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let signedIn = cookies.contains { cookie in
                let domain = cookie.domain.lowercased()
                guard domain.contains("soundcloud.com") else { return false }
                let name = cookie.name.lowercased()
                return name.contains("oauth") || name.contains("session") || name == "user_id"
            }
            DispatchQueue.main.async {
                if signedIn { self?.likelySignedIn = true }
            }
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
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? String, let number = Double(value) { return number }
        return 0
    }

    private static let playCommand = "window.__unixgramSCWeb && window.__unixgramSCWeb.play();"
    private static let pauseCommand = "window.__unixgramSCWeb && window.__unixgramSCWeb.pause();"
    private static let sessionProbeCommand = "window.__unixgramSCWeb && window.__unixgramSCWeb.probeSession();"

    private static let bridgeJavaScript = #"""
    (function() {
      if (window.__unixgramSCWebInstalled) { return; }
      window.__unixgramSCWebInstalled = true;

      function post(type, extra) {
        var payload = extra || {};
        payload.type = type;
        try { window.webkit.messageHandlers.unixgramSoundCloudWeb.postMessage(payload); } catch (_) {}
      }

      var currentAudio = null;

      function audioCandidate() {
        var list = Array.prototype.slice.call(document.querySelectorAll('audio'));
        if (!list.length) { return null; }
        for (var i = 0; i < list.length; i++) {
          if (!list[i].paused) { return list[i]; }
        }
        for (var j = 0; j < list.length; j++) {
          if ((list[j].duration || 0) > 0 || list[j].currentSrc || list[j].src) { return list[j]; }
        }
        return list[0];
      }

      function labelFor(el) {
        return ((el.getAttribute && (el.getAttribute('aria-label') || el.getAttribute('title') || el.getAttribute('data-testid'))) || el.textContent || '').toLowerCase();
      }

      function visible(el) {
        if (!el) { return false; }
        var s = window.getComputedStyle(el);
        var r = el.getBoundingClientRect();
        return s.display !== 'none' && s.visibility !== 'hidden' && r.width >= 0 && r.height >= 0;
      }

      function clickControl(kind) {
        var selectors = kind === 'pause'
          ? ['button[aria-label*="Pause"]', 'button[title*="Pause"]', '.playControls__play.playing', '.sc-button-pause']
          : ['button[aria-label*="Play"]', 'button[title*="Play"]', '.playControls__play', '.sc-button-play'];
        for (var s = 0; s < selectors.length; s++) {
          var direct = document.querySelector(selectors[s]);
          if (direct && visible(direct) && !direct.disabled) { direct.click(); return true; }
        }
        var buttons = Array.prototype.slice.call(document.querySelectorAll('button,[role="button"]'));
        var words = kind === 'pause' ? ['pause', 'пауза'] : ['play', 'воспроизвести', 'слушать'];
        for (var i = 0; i < buttons.length; i++) {
          var label = labelFor(buttons[i]);
          if (visible(buttons[i]) && words.some(function(w) { return label.indexOf(w) !== -1; })) {
            buttons[i].click(); return true;
          }
        }
        return false;
      }

      function loginLikelyRequired() {
        var p = (location.pathname || '').toLowerCase();
        if (p.indexOf('/signin') !== -1 || p.indexOf('/login') !== -1 || p.indexOf('/connect') !== -1) { return true; }
        var text = (document.body && document.body.innerText || '').toLowerCase();
        return text.indexOf('sign in to listen') !== -1 || text.indexOf('sign in to play') !== -1;
      }

      function signedInProbe() {
        var signedIn = !!document.querySelector(
          'a[href^="/you/"], a[href*="/you/library"], button[aria-label*="profile" i], .header__userNavButton, .header__userNavUsernameButton'
        );
        post('loginState', { signedIn: signedIn });
        return signedIn;
      }

      function emitProgress(a) {
        if (!a) { return; }
        post('progress', { position: a.currentTime || 0, duration: isFinite(a.duration) ? (a.duration || 0) : 0 });
      }

      function bindAudio(a) {
        if (!a || a === currentAudio) { return; }
        currentAudio = a;
        a.setAttribute('playsinline', '');
        a.addEventListener('loadedmetadata', function() {
          post('ready', { duration: isFinite(a.duration) ? (a.duration || 0) : 0 });
        });
        a.addEventListener('durationchange', function() {
          post('ready', { duration: isFinite(a.duration) ? (a.duration || 0) : 0 });
        });
        a.addEventListener('play', function() { post('play', {}); });
        a.addEventListener('playing', function() { post('play', {}); });
        a.addEventListener('pause', function() { if (!a.ended) { post('pause', {}); } });
        a.addEventListener('timeupdate', function() { emitProgress(a); });
        a.addEventListener('seeking', function() { emitProgress(a); });
        a.addEventListener('ended', function() { post('finish', {}); });
        a.addEventListener('error', function() {
          post('error', { message: 'SoundCloud Web Player сообщил об ошибке воспроизведения.' });
        });
        post('ready', { duration: isFinite(a.duration) ? (a.duration || 0) : 0 });
      }

      function refresh() {
        bindAudio(audioCandidate());
        signedInProbe();
      }

      window.__unixgramSCWeb = {
        play: function() {
          refresh();
          if (loginLikelyRequired()) { post('loginRequired', {}); return; }
          var a = audioCandidate();
          if (a) {
            try {
              var promise = a.play();
              if (promise && promise.catch) {
                promise.catch(function() { clickControl('play'); });
              }
              return;
            } catch (_) {}
          }
          if (!clickControl('play') && loginLikelyRequired()) { post('loginRequired', {}); }
        },
        pause: function() {
          var a = audioCandidate();
          if (a && !a.paused) { try { a.pause(); return; } catch (_) {} }
          clickControl('pause');
        },
        seek: function(seconds) {
          var a = audioCandidate();
          if (!a || !isFinite(seconds)) { return; }
          try { a.currentTime = Math.max(0, Number(seconds) || 0); emitProgress(a); } catch (_) {}
        },
        setVolume: function(value) {
          var a = audioCandidate();
          if (!a) { return; }
          try { a.volume = Math.max(0, Math.min(1, Number(value) || 0)); } catch (_) {}
        },
        probeSession: signedInProbe
      };

      var observer = new MutationObserver(refresh);
      try { observer.observe(document.documentElement || document, { childList: true, subtree: true }); } catch (_) {}
      setInterval(refresh, 750);
      refresh();
      post('bridgeReady', {});
    })();
    """#
}

/// Attaches the persistent SoundCloud page to the UIKit hierarchy while the
/// native Unixgram Now Playing UI is visible.
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

/// Visible account/session browser for the real SoundCloud website.
/// The same WKWebView is used later as Unixgram's playback engine.
struct SoundCloudWebSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = SoundCloudWidgetEngine.shared

    var body: some View {
        NavigationStack {
            SoundCloudWebViewHost()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("SoundCloud Web")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button("Войти в SoundCloud") { engine.openSignIn() }
                            Button("Открыть SoundCloud") { engine.openSoundCloudHome() }
                            Button("Проверить сессию") { engine.refreshSessionState() }
                        } label: {
                            Image(systemName: engine.likelySignedIn ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") { dismiss() }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if engine.currentPageURL == nil {
                engine.openSignIn()
            }
        }
        .onDisappear {
            engine.refreshSessionState()
            if engine.currentURL != nil {
                engine.resumePendingTrack()
            }
        }
    }
}

private struct SoundCloudWebViewHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .black
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
