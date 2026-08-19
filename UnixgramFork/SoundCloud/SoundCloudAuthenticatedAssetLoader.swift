import Foundation
import AVFoundation
import UniformTypeIdentifiers

/// Feeds SoundCloud HLS to AVFoundation while attaching the OAuth header to every
/// manifest/segment request. AVURLAsset has no supported generic Authorization-header
/// option, so we use AVAssetResourceLoader with a private URL scheme instead.
final class SoundCloudAuthenticatedAssetLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let queue = DispatchQueue(label: "com.aeterna.unixgram.soundcloud.resource-loader")
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    func makeAsset(for url: URL) -> AVURLAsset {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "ugsc"
        let customURL = components?.url ?? url

        let asset = AVURLAsset(url: customURL)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let customURL = loadingRequest.request.url,
              let originalURL = originalHTTPSURL(from: customURL) else {
            loadingRequest.finishLoading(with: URLError(.badURL))
            return false
        }

        let key = ObjectIdentifier(loadingRequest)
        let task = Task { [weak self, weak loadingRequest] in
            guard let self, let loadingRequest else { return }
            do {
                try await self.load(originalURL, into: loadingRequest, allowRefresh: true)
            } catch {
                loadingRequest.finishLoading(with: error)
            }
            self.queue.async { [weak self] in self?.tasks[key] = nil }
        }
        tasks[key] = task
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let key = ObjectIdentifier(loadingRequest)
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    private func load(
        _ url: URL,
        into loadingRequest: AVAssetResourceLoadingRequest,
        allowRefresh: Bool
    ) async throws {
        try Task.checkCancellation()

        let token = try await SoundCloudSession.shared.validAccessToken()
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/*, application/vnd.apple.mpegurl, application/x-mpegURL, */*", forHTTPHeaderField: "Accept")

        if let dataRequest = loadingRequest.dataRequest,
           dataRequest.requestsAllDataToEndOfResource == false,
           dataRequest.requestedLength > 0 {
            let start = dataRequest.currentOffset > 0 ? dataRequest.currentOffset : dataRequest.requestedOffset
            let end = start + Int64(dataRequest.requestedLength) - 1
            request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
        }

        let (rawData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 401, allowRefresh {
            _ = try await SoundCloudSession.shared.forceRefreshAccessToken()
            try await load(url, into: loadingRequest, allowRefresh: false)
            return
        }

        guard (200..<300).contains(http.statusCode) || http.statusCode == 206 else {
            throw NSError(
                domain: "SoundCloudPlayback",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "SoundCloud stream HTTP \(http.statusCode)"]
            )
        }

        let mime = http.mimeType?.lowercased() ?? ""
        let isPlaylist = mime.contains("mpegurl") || url.pathExtension.lowercased() == "m3u8"
        let data = isPlaylist ? rewritePlaylist(rawData, relativeTo: url) : rawData

        if let info = loadingRequest.contentInformationRequest {
            if let mimeType = http.mimeType,
               let type = UTType(mimeType: mimeType) {
                info.contentType = type.identifier
            }
            let totalLength = http.value(forHTTPHeaderField: "Content-Range")
                .flatMap(Self.totalLength(fromContentRange:))
                ?? http.expectedContentLength
            if totalLength >= 0 { info.contentLength = totalLength }
            info.isByteRangeAccessSupported = http.statusCode == 206 || http.value(forHTTPHeaderField: "Accept-Ranges") != nil
        }

        if let dataRequest = loadingRequest.dataRequest {
            dataRequest.respond(with: data)
        }
        loadingRequest.finishLoading()
    }

    private func originalHTTPSURL(from customURL: URL) -> URL? {
        guard customURL.scheme == "ugsc" else { return customURL }
        var components = URLComponents(url: customURL, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }

    private func rewritePlaylist(_ data: Data, relativeTo baseURL: URL) -> Data {
        guard let text = String(data: data, encoding: .utf8) else { return data }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let rewritten = lines.map { line -> String in
            if line.hasPrefix("#") {
                return rewriteURIAttributes(in: line, baseURL: baseURL)
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let absolute = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
                return line
            }
            return customSchemeURL(absolute)?.absoluteString ?? line
        }.joined(separator: "\n")
        return Data(rewritten.utf8)
    }

    private func rewriteURIAttributes(in line: String, baseURL: URL) -> String {
        guard line.contains("URI=\"") else { return line }
        var output = line
        var searchStart = output.startIndex
        while let range = output.range(of: "URI=\"", range: searchStart..<output.endIndex) {
            let valueStart = range.upperBound
            guard let quote = output[valueStart...].firstIndex(of: "\"") else { break }
            let raw = String(output[valueStart..<quote])
            if let absolute = URL(string: raw, relativeTo: baseURL)?.absoluteURL,
               let custom = customSchemeURL(absolute)?.absoluteString {
                output.replaceSubrange(valueStart..<quote, with: custom)
                searchStart = output.index(valueStart, offsetBy: custom.count, limitedBy: output.endIndex) ?? output.endIndex
            } else {
                searchStart = output.index(after: quote)
            }
        }
        return output
    }

    private func customSchemeURL(_ url: URL) -> URL? {
        guard url.scheme == "http" || url.scheme == "https" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "ugsc"
        return components?.url
    }

    private static func totalLength(fromContentRange value: String) -> Int64? {
        guard let slash = value.lastIndex(of: "/") else { return nil }
        return Int64(value[value.index(after: slash)...])
    }
}
