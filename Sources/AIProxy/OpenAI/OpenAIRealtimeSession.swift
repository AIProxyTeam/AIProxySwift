//
//  RealtimeSession.swift
//
//
//  Created by Lou Zell on 11/28/24.
//

import AVFoundation
import Foundation

#if DEBUG
/// A test-only transport seam for deterministic session lifecycle failures.
@AIProxyActor struct OpenAIRealtimeTestTransport: Sendable {
    let send: @AIProxyActor @Sendable (URLSessionWebSocketTask.Message) async throws -> Void
    let receive: @AIProxyActor @Sendable (@escaping @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void) -> Void
    let resume: @AIProxyActor @Sendable () -> Void
    let cancel: @AIProxyActor @Sendable () -> Void
    let closeCode: @AIProxyActor @Sendable () -> URLSessionWebSocketTask.CloseCode
    let closeReason: @AIProxyActor @Sendable () -> Data?
}
#endif

@AIProxyActor open class OpenAIRealtimeSession {
    private enum TerminalState: Sendable {
        case finished
        case failed(Error)
    }

    private let webSocketTask: URLSessionWebSocketTask?
    #if DEBUG
    private let testTransport: OpenAIRealtimeTestTransport?
    #endif
    private var terminalState: TerminalState?
    private var isReceiving = false
    private var receiverStream: AsyncThrowingStream<OpenAIRealtimeMessage, Error>?
    private var continuation: AsyncThrowingStream<OpenAIRealtimeMessage, Error>.Continuation?
    let sessionConfiguration: OpenAIRealtimeSessionConfiguration

    init(
        webSocketTask: URLSessionWebSocketTask,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration
    ) {
        self.webSocketTask = webSocketTask
        #if DEBUG
        self.testTransport = nil
        #endif
        self.sessionConfiguration = sessionConfiguration
        self.start()
    }

    #if DEBUG
    init(
        testTransport: OpenAIRealtimeTestTransport,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration
    ) {
        self.webSocketTask = nil
        self.testTransport = testTransport
        self.sessionConfiguration = sessionConfiguration
        self.start()
    }
    #endif

    deinit {
        continuation?.finish()
        if terminalState == nil {
            webSocketTask?.cancel()
            #if DEBUG
            if let testTransport {
                Task { @AIProxyActor in testTransport.cancel() }
            }
            #endif
        }
        logIf(.debug)?.debug("OpenAIRealtimeSession is being freed")
    }

    /// Server events for one receiving task. Provider error events remain message data.
    /// Transport and decoding failures terminate the stream with their cause.
    /// Cancelling while awaiting the next event closes the session.
    /// Use `defer { session.disconnect() }` in the receiving task so cancellation
    /// during event handling and early exits also close the session.
    public var receiver: AsyncThrowingStream<OpenAIRealtimeMessage, Error> {
        if let receiverStream {
            return receiverStream
        }
        let stream = AsyncThrowingStream<OpenAIRealtimeMessage, Error> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination {
                    Task { @AIProxyActor [weak self] in self?.disconnect() }
                }
            }
            // Retain terminal failures even when no receiving task was attached yet.
            // Events arriving before the receiver is requested are not buffered.
            if let terminalState = self.terminalState {
                self.finish(continuation, with: terminalState)
                self.continuation = nil
            }
        }
        self.receiverStream = stream
        return stream
    }

    /// Completes when serialization and the transport send succeed, without implying
    /// provider acknowledgement. Serialization and send failures are thrown unchanged.
    public func sendMessage(_ encodable: Encodable) async throws {
        guard terminalState == nil else {
            throw OpenAIRealtimeSessionError.disconnected
        }
        let message = URLSessionWebSocketTask.Message.string(try encodable.serialize())
        try await self.sendOperation(message)
    }

    /// Closes the session and finishes its receiver normally. Repeated calls are safe.
    public func disconnect() {
        self.terminate(.finished)
    }

    private func start() {
        self.resumeTransport()
        self.receiveMessage()
        do {
            let message = URLSessionWebSocketTask.Message.string(
                try OpenAIRealtimeSessionUpdate(session: self.sessionConfiguration).serialize()
            )
            // Capture the transport, not the session, across a potentially pending send.
            let send = self.sendOperation
            Task { @AIProxyActor [weak self] in
                guard self != nil, self?.terminalState == nil else { return }
                do {
                    try await send(message)
                } catch {
                    self?.terminate(.failed(error))
                }
            }
        } catch {
            self.terminate(.failed(error))
        }
    }

    private var sendOperation: @AIProxyActor @Sendable (URLSessionWebSocketTask.Message) async throws -> Void {
        #if DEBUG
        if let testTransport {
            return testTransport.send
        }
        #endif
        let task = self.webSocketTask
        return { message in
            guard let task else {
                throw AIProxyError.assertion("The Realtime session has no WebSocket transport")
            }
            try await task.send(message)
        }
    }

    private func resumeTransport() {
        #if DEBUG
        if let testTransport {
            testTransport.resume()
            return
        }
        #endif
        self.webSocketTask?.resume()
    }

    private func cancelTransport() {
        #if DEBUG
        if let testTransport {
            testTransport.cancel()
            return
        }
        #endif
        self.webSocketTask?.cancel()
    }

    private var closeCode: URLSessionWebSocketTask.CloseCode {
        #if DEBUG
        if let testTransport { return testTransport.closeCode() }
        #endif
        return self.webSocketTask?.closeCode ?? .invalid
    }

    private var closeReason: Data? {
        #if DEBUG
        if let testTransport { return testTransport.closeReason() }
        #endif
        return self.webSocketTask?.closeReason
    }

    private func receiveMessage() {
        guard terminalState == nil, !isReceiving else { return }
        self.isReceiving = true
        let receive: @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void = { [weak self] result in
            Task { @AIProxyActor [weak self] in self?.didReceive(result) }
        }
        #if DEBUG
        if let testTransport {
            testTransport.receive(receive)
            return
        }
        #endif
        self.webSocketTask?.receive(completionHandler: receive)
    }

    private func didReceive(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        guard terminalState == nil else { return }
        self.isReceiving = false
        switch result {
        case .failure(let error):
            // A normal frame, an abnormal frame, and a dropped socket can all produce
            // the same NSError. Only supplied close metadata confirms a remote close.
            switch self.closeCode {
            case .normalClosure:
                self.terminate(.finished)
            case .invalid:
                self.terminate(.failed(error))
            default:
                self.terminate(.failed(OpenAIRealtimeSessionError.closed(
                    code: self.closeCode.rawValue,
                    reason: self.closeReason,
                    underlyingError: error
                )))
            }
        case .success(let message):
            let data: Data
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default:
                self.terminate(.failed(AIProxyError.assertion("Received an unsupported WebSocket message format")))
                return
            }
            do {
                let event = try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: data)
                if let continuation, case .terminated = continuation.yield(event) {
                    self.terminate(.finished)
                    return
                }
                self.receiveMessage()
            } catch {
                self.terminate(.failed(error))
            }
        }
    }

    private func terminate(_ state: TerminalState) {
        guard terminalState == nil else { return }
        self.terminalState = state
        if let continuation {
            self.finish(continuation, with: state)
            self.continuation = nil
        }
        self.cancelTransport()
    }

    private func finish(
        _ continuation: AsyncThrowingStream<OpenAIRealtimeMessage, Error>.Continuation,
        with state: TerminalState
    ) {
        switch state {
        case .finished: continuation.finish()
        case .failed(let error): continuation.finish(throwing: error)
        }
    }
}
