import Foundation

/// Каркас нативного UnixProto transport.
///
/// Публичная спецификация Unixgram описывает:
/// - TCP transport
/// - 5 вариантов framing
/// - X25519 handshake
/// - HKDF-SHA256
/// - encrypted packet channel
/// - session recovery
///
/// Здесь намеренно нет выдуманных серверных адресов/ключей/методов.
actor UnixProtoTransport {
    enum TransportKind {
        case legacy
        case abridged
        case intermediate
        case paddedIntermediate
        case full
    }

    private(set) var isConnected = false

    func connect() async throws {
        // TODO:
        // 1. Получить официальные gateway host/port.
        // 2. Выполнить handshake согласно опубликованной спецификации.
        // 3. Проверить pinned server signature key.
        // 4. Вывести auth key через X25519 + HKDF-SHA256.
        // 5. Запустить framed encrypted channel.
        throw UnixProtoError.configurationMissing
    }

    func disconnect() {
        isConnected = false
    }
}

enum UnixProtoError: Error {
    case configurationMissing
}
