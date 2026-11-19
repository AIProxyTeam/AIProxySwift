import Foundation

/// Session state and confirmed WebSocket closure failures. Unclassified transport,
/// serialization and decoding errors are forwarded without this wrapper.
nonisolated public enum OpenAIRealtimeSessionError: LocalizedError, Sendable {
    /// A message was sent after the session had finished or disconnected.
    case disconnected

    /// A confirmed abnormal close, retaining the supplied close frame and the
    /// original transport failure when one was provided.
    case closed(code: Int, reason: Data?, underlyingError: Error?)

    public var errorDescription: String? {
        switch self {
        case .disconnected:
            return "The Realtime session is disconnected."
        case .closed(let code, let reason, _):
            if let reason, let text = String(data: reason, encoding: .utf8), !text.isEmpty {
                return "The Realtime WebSocket closed with code \(code): \(text)"
            }
            return "The Realtime WebSocket closed with code \(code)."
        }
    }
}
