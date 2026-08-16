import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://web.unixgram.com")!

    // Эти пути опубликованы Unixgram.
    static let csrfPath = "/api/auth/csrf"
    static let realtimeSSEPath = "/api/realtime/events"

    // Остальные endpoint'ы НЕ выдумываем.
    // Добавлять только после официальной документации/доступа.
}
