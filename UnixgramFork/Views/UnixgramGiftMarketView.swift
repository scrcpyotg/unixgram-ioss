import SwiftUI
import WebKit

/// Native Gifts market UI.
///
/// The user never sees Unixgram's web page. Until Unixgram exposes/captures the
/// direct gift-catalog + purchase HTTP routes, a hidden persistent WebKit bridge
/// is used only as a compatibility transport to read the official live catalog
/// and submit the official purchase action. The visible experience is 100% SwiftUI.
struct UnixgramGiftMarketView: View {
    let username: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var liveSession: UnixgramLiveSession
    @StateObject private var commerce = UnixgramCommerceStore.shared

    @State private var catalog: [UnixgramNativeGiftItem] = []
    @State private var bridgeStatus = "Подключаем маркет…"
    @State private var command: UnixgramGiftBridgeCommand?
    @State private var selectedGift: UnixgramNativeGiftItem?
    @State private var pendingPurchase: UnixgramNativeGiftItem?
    @State private var purchaseMessage: String?
    @State private var bridgeReady = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    balanceCard
                    marketStatus

                    if !catalog.isEmpty {
                        Text("Маркет подарков")
                            .font(.system(size: 23, weight: .bold))
                            .padding(.horizontal, 18)

                        giftGrid(catalog)
                            .padding(.horizontal, 18)
                    } else {
                        loadingState
                    }
                }
                .padding(.bottom, 36)
            }

            // Compatibility transport only. It is deliberately not presented to the user.
            UnixgramGiftBackgroundBridge(
                username: username,
                command: $command,
                catalog: $catalog,
                status: $bridgeStatus,
                purchaseMessage: $purchaseMessage,
                isReady: $bridgeReady
            )
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            await commerce.refreshStars(fallback: liveSession.currentUser)
        }
        .sheet(item: $selectedGift) { gift in
            giftDetail(gift)
                .presentationDetents([.medium, .large])
                .unixgramPresentationCornerRadius(28)
        }
        .confirmationDialog(
            pendingPurchase.map { "Купить \($0.title)?" } ?? "Купить подарок?",
            isPresented: Binding(
                get: { pendingPurchase != nil },
                set: { if !$0 { pendingPurchase = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let gift = pendingPurchase, gift.marketIndex != nil {
                Button(purchaseButtonTitle(gift)) {
                    guard let index = gift.marketIndex else { return }
                    selectedGift = nil
                    pendingPurchase = nil
                    purchaseMessage = nil
                    command = .purchase(index: index)
                }
            }
            Button("Отмена", role: .cancel) { pendingPurchase = nil }
        } message: {
            if let gift = pendingPurchase {
                Text("Покупка будет отправлена в настоящий Unixgram с текущего аккаунта.")
            }
        }
        .alert("Gifts", isPresented: Binding(
            get: { purchaseMessage != nil },
            set: { if !$0 { purchaseMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.08), in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Маркет подарков")
                    .font(.system(size: 27, weight: .bold))
                Text("Нативный интерфейс · реальные данные Unixgram")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                bridgeStatus = "Обновляем каталог…"
                command = .refreshCatalog
                Task { await commerce.refreshStars(fallback: liveSession.currentUser) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var balanceCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "star.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
                .frame(width: 56, height: 56)
                .background(Color.orange.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Ваш баланс")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(starsText)
                    .font(.system(size: 28, weight: .bold))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 18)
    }

    private var marketStatus: some View {
        HStack(spacing: 9) {
            if !bridgeReady {
                ProgressView().controlSize(.small).tint(.purple)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text(bridgeStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func giftGrid(_ items: [UnixgramNativeGiftItem]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items) { gift in
                Button { selectedGift = gift } label: {
                    nativeGiftCard(gift)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func nativeGiftCard(_ gift: UnixgramNativeGiftItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.22), Color.white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let raw = gift.imageURL, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        default: Image(systemName: "gift.fill").font(.system(size: 44)).foregroundStyle(.purple)
                        }
                    }
                    .padding(16)
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.purple)
                }
            }
            .frame(height: 145)

            Text(gift.title)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(2)

            if let price = gift.priceStars {
                Label("\(price)", systemImage: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)
            } else if let subtitle = gift.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            if bridgeReady {
                Image(systemName: "gift.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Каталог Gifts не удалось распознать")
                    .font(.system(size: 16, weight: .bold))
                Text("Показываем только настоящий маркет Unixgram — demo-карточки сюда не подмешиваются.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    bridgeReady = false
                    bridgeStatus = "Повторно синхронизируем Gifts…"
                    command = .refreshCatalog
                } label: {
                    Label("Обновить каталог", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                ProgressView().tint(.purple).scaleEffect(1.15)
                Text("Получаем настоящий каталог Gifts…")
                    .font(.system(size: 15, weight: .semibold))
                Text("Никаких demo-подарков в этот экран не подмешивается.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 60)
    }

    private func giftDetail(_ gift: UnixgramNativeGiftItem) -> some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.white.opacity(0.18)).frame(width: 42, height: 5).padding(.top, 10)

            nativeGiftCard(gift)
                .frame(maxWidth: 280)

            if let subtitle = gift.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if gift.marketIndex != nil {
                Button {
                    pendingPurchase = gift
                } label: {
                    Label(purchaseButtonTitle(gift), systemImage: "gift.fill")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private var starsText: String {
        if let balance = commerce.starsBalance ?? liveSession.currentUser?.resolvedStarsBalance {
            return "\(balance) ⭐"
        }
        return commerce.isRefreshingStars ? "…" : "—"
    }

    private func purchaseButtonTitle(_ gift: UnixgramNativeGiftItem) -> String {
        if let price = gift.priceStars { return "Купить за \(price) ⭐" }
        return "Купить подарок"
    }


}

struct UnixgramNativeGiftItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let imageURL: String?
    let priceStars: Int?
    let marketIndex: Int?
}

private enum UnixgramGiftBridgeCommand: Equatable {
    case refreshCatalog
    case purchase(index: Int)
}

private struct UnixgramGiftBackgroundBridge: UIViewRepresentable {
    let username: String
    @Binding var command: UnixgramGiftBridgeCommand?
    @Binding var catalog: [UnixgramNativeGiftItem]
    @Binding var status: String
    @Binding var purchaseMessage: String?
    @Binding var isReady: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            catalog: $catalog,
            status: $status,
            purchaseMessage: $purchaseMessage,
            isReady: $isReady
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "giftBridge")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        let escaped = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        if let url = URL(string: "https://unixgram.com/u/\(escaped)") {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 30
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let command else { return }
        DispatchQueue.main.async {
            switch command {
            case .refreshCatalog:
                context.coordinator.discoverCatalog()
            case .purchase(let index):
                context.coordinator.purchase(index: index)
            }
            self.command = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var catalog: [UnixgramNativeGiftItem]
        @Binding var status: String
        @Binding var purchaseMessage: String?
        @Binding var isReady: Bool
        weak var webView: WKWebView?

        init(
            catalog: Binding<[UnixgramNativeGiftItem]>,
            status: Binding<String>,
            purchaseMessage: Binding<String?>,
            isReady: Binding<Bool>
        ) {
            _catalog = catalog
            _status = status
            _purchaseMessage = purchaseMessage
            _isReady = isReady
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            discoverCatalog()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status = "Маркет временно недоступен"
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            status = "Маркет временно недоступен"
        }

        func discoverCatalog() {
            guard let webView else { return }
            status = "Синхронизируем Gifts…"

            let script = #"""
            (async () => {
              const sleep = (ms) => new Promise(r => setTimeout(r, ms));
              const text = (el) => ((el?.innerText || el?.textContent || '') + '').trim();
              const allClickable = () => Array.from(document.querySelectorAll('button,a,[role="tab"],[role="button"]'));
              const byText = (parts) => allClickable().find(el => {
                const t = text(el).toLowerCase();
                return parts.some(p => t === p || t.includes(p));
              });

              const giftsTab = byText(['gifts','подарки']);
              if (giftsTab) { giftsTab.click(); await sleep(850); }

              const market = byText(['маркет подарков','gift market','магазин подарков','market gifts']);
              if (market) { market.click(); await sleep(1100); }

              const nodes = Array.from(document.querySelectorAll('[data-gift-id],[data-gift],article,li,button,[role="button"],a'));
              const result = [];
              const refs = [];
              const seen = new Set();

              for (const el of nodes) {
                const t = text(el);
                const img = el.querySelector?.('img');
                const priceMatch = t.match(/(?:⭐\s*([0-9][0-9\s]*)|([0-9][0-9\s]*)\s*(?:⭐|stars?|зв[её]зд))/i);
                if (!img && !priceMatch) continue;
                if (!priceMatch) continue;

                const lines = t.split(/\n+/).map(v => v.trim()).filter(Boolean);
                const title = (el.getAttribute?.('data-title') || lines.find(v => !/(⭐|stars?|зв[её]зд)/i.test(v)) || 'Подарок').slice(0, 80);
                const rawPrice = (priceMatch[1] || priceMatch[2] || '').replace(/\s/g, '');
                const price = parseInt(rawPrice, 10);
                const image = img?.src || null;
                const key = `${title}|${price || ''}|${image || ''}`;
                if (seen.has(key)) continue;
                seen.add(key);

                refs.push(el);
                result.push({
                  id: el.getAttribute?.('data-gift-id') || el.getAttribute?.('data-gift') || `market-${result.length}`,
                  title,
                  subtitle: lines.slice(1, 4).join(' · ').slice(0, 180) || null,
                  imageURL: image,
                  priceStars: Number.isFinite(price) ? price : null,
                  marketIndex: result.length
                });
              }

              window.__unixgramNativeGiftRefs = refs;
              window.webkit.messageHandlers.giftBridge.postMessage({type:'catalog', items:result});
            })();
            """#

            webView.evaluateJavaScript(script)
        }

        func purchase(index: Int) {
            guard let webView else { return }
            status = "Оформляем покупку…"

            let script = #"""
            (async () => {
              const sleep = (ms) => new Promise(r => setTimeout(r, ms));
              const refs = window.__unixgramNativeGiftRefs || [];
              const card = refs[\#(index)];
              if (!card) {
                window.webkit.messageHandlers.giftBridge.postMessage({type:'purchase', ok:false, message:'Подарок исчез из каталога. Обновите маркет.'});
                return;
              }

              card.click();
              await sleep(650);

              const nodes = Array.from(document.querySelectorAll('button,[role="button"],a'));
              const buy = nodes.find(el => {
                const t = ((el.innerText || el.textContent || '') + '').trim().toLowerCase();
                return /купить|purchase|buy|отправить подарок|send gift/.test(t) && !el.disabled;
              });

              if (!buy) {
                window.webkit.messageHandlers.giftBridge.postMessage({type:'purchase', ok:false, message:'Unixgram запросил дополнительный шаг. Нужен новый HAR покупки, чтобы перенести его в нативный экран.'});
                return;
              }

              buy.click();
              await sleep(1000);
              const body = (document.body?.innerText || '').toLowerCase();
              const failed = /недостаточно|insufficient|ошибка|error|failed/.test(body);
              window.webkit.messageHandlers.giftBridge.postMessage({
                type:'purchase',
                ok:!failed,
                message: failed ? 'Unixgram не подтвердил покупку. Проверьте баланс или повторите.' : 'Запрос покупки отправлен в Unixgram.'
              });
            })();
            """#

            webView.evaluateJavaScript(script)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "giftBridge",
                  let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String else { return }

            if type == "catalog" {
                let rawItems = payload["items"] as? [[String: Any]] ?? []
                let decoded: [UnixgramNativeGiftItem] = rawItems.enumerated().compactMap { offset, raw in
                    let title = (raw["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let title, !title.isEmpty else { return nil }
                    let marketIndex = (raw["marketIndex"] as? NSNumber)?.intValue ?? offset
                    return UnixgramNativeGiftItem(
                        id: (raw["id"] as? String) ?? "market-\(marketIndex)",
                        title: title,
                        subtitle: raw["subtitle"] as? String,
                        imageURL: raw["imageURL"] as? String,
                        priceStars: (raw["priceStars"] as? NSNumber)?.intValue,
                        marketIndex: marketIndex
                    )
                }

                catalog = decoded
                isReady = true
                status = decoded.isEmpty
                    ? "Каталог открыт, но карточки покупки не найдены"
                    : "\(decoded.count) подарков · данные Unixgram"
            } else if type == "purchase" {
                let ok = payload["ok"] as? Bool ?? false
                let text = payload["message"] as? String ?? (ok ? "Покупка отправлена" : "Не удалось купить подарок")
                purchaseMessage = text
                status = ok ? "Unixgram принял запрос" : "Покупка не завершена"
            }
        }
    }
}
