//
//  RealtimeSession.swift
//
//
//  Created by Lou Zell on 11/28/24.
//

import AVFoundation
import Foundation

/// The operations needed by a Realtime session, backed by a WebSocket task in production.
nonisolated struct OpenAIRealtimeTransport: Sendable {
    let send: @AIProxyActor @Sendable (URLSessionWebSocketTask.Message) async throws -> Void
    let receive: @AIProxyActor @Sendable (@escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) -> Void
    let resume: @AIProxyActor @Sendable () -> Void
    let cancel: @AIProxyActor @Sendable () -> Void
    let closeCode: @AIProxyActor @Sendable () -> URLSessionWebSocketTask.CloseCode
    let closeReason: @AIProxyActor @Sendable () -> Data?
}

@AIProxyActor open class OpenAIRealtimeSession {
    private let webSocketTask: URLSessionWebSocketTask?
    private let transport: OpenAIRealtimeTransport
    private var isTerminated = false
    private var isReceiving = false
    private let receiverStream: AsyncThrowingStream<OpenAIRealtimeMessage, Error>
    private let continuation: AsyncThrowingStream<OpenAIRealtimeMessage, Error>.Continuation
    let sessionConfiguration: OpenAIRealtimeSessionConfiguration

    convenience init(
        webSocketTask: URLSessionWebSocketTask,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration
    ) {
        self.init(
            transport: OpenAIRealtimeTransport(
                send: { try await webSocketTask.send($0) },
                receive: { webSocketTask.receive(completionHandler: $0) },
                resume: { webSocketTask.resume() },
                cancel: { webSocketTask.cancel() },
                closeCode: { webSocketTask.closeCode },
                closeReason: { webSocketTask.closeReason }
            ),
            webSocketTask: webSocketTask,
            sessionConfiguration: sessionConfiguration
        )
    }

    init(
        transport: OpenAIRealtimeTransport,
        webSocketTask: URLSessionWebSocketTask? = nil,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration
    ) {
        let (receiver, continuation) = AsyncThrowingStream<OpenAIRealtimeMessage, Error>.makeStream()
        self.webSocketTask = webSocketTask
        self.transport = transport
        self.receiverStream = receiver
        self.continuation = continuation
        self.sessionConfiguration = sessionConfiguration
        self.start()
    }

    deinit {
        continuation.finish()
        if !isTerminated {
            if let webSocketTask {
                webSocketTask.cancel()
            } else {
                let transport = self.transport
                Task { @AIProxyActor in transport.cancel() }
            }
        }
        logIf(.debug)?.debug("OpenAIRealtimeSession is being freed")
    }

    /// Server events for one receiving task. Provider error events remain message data.
    /// Transport and decoding failures terminate the stream with their cause.
    /// The stream is created before the transport starts and buffers events without
    /// a fixed limit until consumed. Start consuming it promptly.
    /// Cancelling while awaiting the next event closes the session.
    /// Use `defer { session.disconnect() }` in the receiving task so cancellation
    /// during event handling and early exits also close the session.
    public var receiver: AsyncThrowingStream<OpenAIRealtimeMessage, Error> {
        receiverStream
    }

    /// Completes when serialization and the transport send succeed, without implying
    /// provider acknowledgement. Serialization and send failures are thrown unchanged.
    public func sendMessage(_ encodable: Encodable) async throws {
        guard !isTerminated else {
            logIf(.debug)?.debug("Ignoring Realtime send: session is disconnected")
            throw OpenAIRealtimeSessionError.disconnected
        }
        do {
            let message = URLSessionWebSocketTask.Message.string(try encodable.serialize())
            try await self.transport.send(message)
        } catch {
            let code = (error as NSError).code
            logIf(.error)?.error("Realtime send failed (code: \(code, privacy: .public)): \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }

    /// Closes the session and finishes its receiver normally. Repeated calls are safe.
    public func disconnect() {
        self.terminate()
    }

    private func start() {
        self.continuation.onTermination = { [weak self] termination in
            if case .cancelled = termination {
                Task { @AIProxyActor [weak self] in self?.disconnect() }
            }
        }
        self.transport.resume()
        self.receiveMessage()
        do {
            let message = URLSessionWebSocketTask.Message.string(
                try OpenAIRealtimeSessionUpdate(session: self.sessionConfiguration).serialize()
            )
            // Capture the transport, not the session, across a potentially pending send.
            let send = self.transport.send
            Task { @AIProxyActor [weak self] in
                guard self != nil, self?.isTerminated == false else { return }
                do {
                    try await send(message)
                } catch {
                    self?.fail(error, category: "initial send")
                }
            }
        } catch {
            self.fail(error, category: "initial send")
        }
    }

    private func receiveMessage() {
        guard !isTerminated, !isReceiving else { return }
        self.isReceiving = true
        let receive: @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void = { [weak self] result in
            Task { @AIProxyActor [weak self] in self?.didReceive(result) }
        }
        self.transport.receive(receive)
    }

    private func didReceive(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        guard !isTerminated else { return }
        self.isReceiving = false
        switch result {
        case .failure(let error):
            // A normal frame, an abnormal frame, and a dropped socket can all produce
            // the same NSError. Only supplied close metadata confirms a remote close.
            switch self.transport.closeCode() {
            case .normalClosure:
                self.terminate()
            case .invalid:
                self.fail(error, category: "receive")
            default:
                let closed = OpenAIRealtimeSessionError.closed(
                    code: self.transport.closeCode().rawValue,
                    reason: self.transport.closeReason(),
                    underlyingError: error
                )
                self.fail(closed, category: "receive", code: self.transport.closeCode().rawValue)
            }
        case .success(let message):
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default:
                self.fail(AIProxyError.assertion("Received an unsupported WebSocket message format"), category: "receive")
                return
            }
            do {
                let event = try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: data)
                if case .error(let providerError) = event {
                    let details = providerError.error?.message ?? providerError.error?.code ?? providerError.error?.type ?? "No error details"
                    logIf(.error)?.error("Realtime provider error: \(details, privacy: .private)")
                }
                if case .terminated = continuation.yield(event) {
                    self.terminate()
                    return
                }
                self.receiveMessage()
            } catch {
                self.fail(error, category: "decode", bytes: data.count)
            }
        }
    }

    private func fail(_ error: Error, category: String, code: Int? = nil, bytes: Int? = nil) {
        guard !isTerminated else { return }
        if let bytes {
            let errorType = String(reflecting: type(of: error))
            logIf(.error)?.error("Realtime decode failed (bytes: \(bytes, privacy: .public), type: \(errorType, privacy: .public))")
        } else {
            let errorCode = code ?? (error as NSError).code
            logIf(.error)?.error("Realtime \(category, privacy: .public) failed (code: \(errorCode, privacy: .public)): \(error.localizedDescription, privacy: .private)")
        }
        self.terminate(throwing: error)
    }

    private func terminate(throwing error: Error? = nil) {
        guard !isTerminated else { return }
        self.isTerminated = true
        self.continuation.finish(throwing: error)
        self.transport.cancel()
    }
}
