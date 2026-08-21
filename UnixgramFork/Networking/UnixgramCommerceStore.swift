import Foundation
import SwiftUI
import WebKit

@MainActor
final class UnixgramCommerceStore: ObservableObject {
    static let shared = UnixgramCommerceStore()

    @Published private(set) var starsBalance: Int?
    @Published private(set) var isRefreshingStars = false
    @Published private(set) var lastError: String?

    private init() {}

    /// Applies the exact post-donation balance returned by Unixgram.
    /// This avoids waiting for UnixPlace/account caches to catch up after a Stars transfer.
    func applyConfirmedStarsBalance(_ balance: Int) {
        starsBalance = max(0, balance)
        lastError = nil
    }

    func refreshStars(fallback account: UGCurrentAccount?) async {
        guard !isRefreshingStars else { return }
        isRefreshingStars = true
        defer { isRefreshingStars = false }

        if let direct = account?.resolvedStarsBalance {
            starsBalance = direct
        }

        do {
            if let placeBalance = try await UnixgramCommerceClient.shared.unixPlaceStarsBalance() {
                starsBalance = placeBalance
            }
            lastError = nil
        } catch {
            // Keep the last confirmed balance. Stars are supplemental UI data and a
            // temporary UnixPlace failure must not blank the whole home screen.
            lastError = error.localizedDescription
        }
    }
}

actor UnixgramCommerceClient {
    static let shared = UnixgramCommerceClient()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpCookieStorage = .shared
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    /// UnixPlace already renders the authenticated Unixgram account in its server
    /// component payload, including `starsBalance`. We reuse that real value instead
    /// of showing a placeholder when `/api/auth/me` omits the field.
    func unixPlaceStarsBalance() async throws -> Int? {
        await UnixgramRealAPIClient.shared.importWebKitCookies()

        guard let url = URL(string: "https://place.unixgram.com/") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("https://unixgram.com/", forHTTPHeaderField: "Referer")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<400).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        let patterns = [
            #"\\\"starsBalance\\\"\s*:\s*(\d+)"#,
            #""starsBalance"\s*:\s*(\d+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                    in: html,
                    range: NSRange(html.startIndex..<html.endIndex, in: html)
               ),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html),
               let value = Int(html[range]) {
                return value
            }
        }

        return nil
    }
}
