import Foundation

@MainActor
final class SSERealtimeClient: ObservableObject {
    @Published private(set) var isConnected = false

    private var task: Task<Void, Never>?

    func connect() {
        disconnect()

        task = Task {
            let url = APIConfig.baseURL.appending(path: APIConfig.realtimeSSEPath)
            var request = URLRequest(url: url)
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    isConnected = false
                    return
                }

                isConnected = true
                for try await line in bytes.lines {
                    guard !Task.isCancelled else { break }
                    handle(line: line)
                }
            } catch {
                isConnected = false
            }
        }
    }

    func disconnect() {
        task?.cancel()
        task = nil
        isConnected = false
    }

    private func handle(line: String) {
        // Unixgram документирует события вроде:
        // message:new, post:deleted, feed:new, stars:balance
        // payload-схемы добавим после публикации.
        if line.hasPrefix("event:") {
            let event = line.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            print("Unixgram SSE event:", event)
        }
    }
}
