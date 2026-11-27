//
//  RealtimeSession.swift
//
//
//  Created by Lou Zell on 11/28/24.
//

import Foundation
import Network

/// Native operations shared by the session and its deterministic lifecycle tests.
nonisolated struct OpenAIRealtimeTransport: Sendable {
    enum Frame: Sendable {
        case message(Data)
        case receiveAgain
        case closed(code: Int, reason: Data?, error: Error?)
    }

    typealias SendCompletion = @Sendable (Error?) -> Void
    typealias ReceiveCompletion = @Sendable (Result<Frame, Error>) -> Void
    let send: @AIProxyActor @Sendable (Data, @escaping SendCompletion) -> Void
    let receive: @AIProxyActor @Sendable (@escaping ReceiveCompletion) -> Void
    let state: @AIProxyActor @Sendable () -> NWConnection.State
    let start: @AIProxyActor @Sendable (@escaping @Sendable (NWConnection.State) -> Void) -> Void
    let cancel: @AIProxyActor @Sendable () -> Void

    static func network(_ connection: NWConnection) -> Self {
        Self(
            send: { data, completion in
                let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
                let context = NWConnection.ContentContext(identifier: "websocket", metadata: [metadata])
                connection.send(content: data, contentContext: context, isComplete: true,
                                completion: .contentProcessed { error in completion(error) })
            },
            receive: { completion in
                connection.receiveMessage(completion: receiveHandler(completion))
            },
            state: { connection.state },
            start: { stateChanged in
                connection.stateUpdateHandler = stateChanged
                connection.start(queue: DispatchQueue(label: "com.aiproxy.realtime", qos: .userInitiated))
            },
            cancel: {
                connection.stateUpdateHandler = nil
                connection.cancel()
            }
        )
    }

    /// Network invokes this callback on its queue, outside AIProxyActor.
    private static func receiveHandler(_ completion: @escaping ReceiveCompletion)
        -> @Sendable (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void {
        { content, context, isComplete, error in
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                as? NWProtocolWebSocket.Metadata
            if let metadata, metadata.opcode == .close {
                let code: Int
                switch metadata.closeCode {
                case .protocolCode(let value): code = Int(value.rawValue)
                case .applicationCode(let value), .privateCode(let value): code = Int(value)
                @unknown default:
                    completion(.failure(error ?? AIProxyError.assertion("Unsupported WebSocket close metadata")))
                    return
                }
                // Network supplies the reason as content, excluding the two status bytes.
                completion(.success(.closed(code: code, reason: content, error: error)))
            } else if let error, !isComplete || (metadata == nil && content == nil) {
                // A socket error can accompany each complete buffered frame,
                // including valid events preceding a close. Consume those first.
                completion(.failure(error))
            } else if metadata?.opcode == .ping || metadata?.opcode == .pong {
                completion(.success(.receiveAgain))
            } else if metadata == nil && content == nil {
                // Network can signal EOF before reporting the actual socket error
                // on the next receive. This is distinct from an empty WebSocket frame.
                completion(.success(.receiveAgain))
            } else {
                // JSON can arrive as either text or binary. An empty message must
                // reach the decoder as well so callers see its original failure.
                completion(.success(.message(content ?? Data())))
            }
        }
    }
}

@AIProxyActor open class OpenAIRealtimeSession {
    private let transport: OpenAIRealtimeTransport
    private let setupTimeout: TimeInterval
    private var setupDeadline: Task<Void, Never>?
    private var isTerminated = false
    private var hasStarted = false
    private var isReceiving = false
    private let receiverStream: AsyncThrowingStream<OpenAIRealtimeMessage, Error>
    private let continuation: AsyncThrowingStream<OpenAIRealtimeMessage, Error>.Continuation
    let sessionConfiguration: OpenAIRealtimeSessionConfiguration

    convenience init(
        connection: NWConnection,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration,
        setupTimeout: TimeInterval = 60
    ) {
        self.init(transport: .network(connection), sessionConfiguration: sessionConfiguration, setupTimeout: setupTimeout)
    }

    init(
        transport: OpenAIRealtimeTransport,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration,
        setupTimeout: TimeInterval = 60
    ) {
        let (receiver, continuation) = AsyncThrowingStream<OpenAIRealtimeMessage, Error>.makeStream()
        self.transport = transport
        self.setupTimeout = setupTimeout
        self.receiverStream = receiver
        self.continuation = continuation
        self.sessionConfiguration = sessionConfiguration
    }

    deinit {
        setupDeadline?.cancel()
        continuation.finish()
        if !isTerminated {
            let cancel = transport.cancel
            Task { @AIProxyActor in cancel() }
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
            let data: Data = try encodable.serialize()
            let error = await withCheckedContinuation { continuation in
                self.transport.send(data) { continuation.resume(returning: $0) }
            }
            if let error { throw error }
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

    func start() {
        guard !hasStarted, !isTerminated else { return }
        hasStarted = true
        self.continuation.onTermination = { [weak self] termination in
            if case .cancelled = termination {
                Task { @AIProxyActor [weak self] in self?.disconnect() }
            }
        }
        let timeout = setupTimeout.isFinite ? max(0, setupTimeout) : 60
        let capped = min(timeout, TimeInterval(UInt64.max / 1_000_000_000))
        self.setupDeadline = Task { @AIProxyActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(capped * 1_000_000_000)) }
            catch { return }
            self?.setupDeadlineReached()
        }
        self.transport.start { [weak self] state in
            Task { @AIProxyActor [weak self] in self?.handleConnectionState(state) }
        }

        // Network queues operations during setup. Arm the receiver first and
        // submit configuration before returning to callers that can send commands.
        self.receiveMessage()
        do {
            let update = OpenAIRealtimeSessionUpdate(session: self.sessionConfiguration)
            self.transport.send(try update.serialize()) { [weak self] error in
                guard let error else { return }
                Task { @AIProxyActor [weak self] in
                    guard let self else { return }
                    // Setup failure is handled by the state callback. After setup,
                    // the receiver drains any buffered events and the peer's close.
                    if case .failed = self.transport.state() { return }
                    self.fail(error, category: "initial send")
                }
            }
        } catch {
            self.fail(error, category: "initial send")
        }
    }

    func handleConnectionState(_ state: NWConnection.State) {
        guard !isTerminated else { return }
        switch state {
        case .ready:
            self.cancelSetupDeadline()
        case .failed(let error):
            // An established connection can report ENOTCONN before its buffered
            // messages and close frame have been received. Let the outstanding
            // receive drain them and deliver either the close or its socket error.
            if setupDeadline != nil { self.fail(error, category: "connection") }
        case .waiting(let error):
            // Network can retry transient path failures. TLS failures, rejected
            // upgrades and refused endpoints should surface their original cause.
            switch error {
            case .posix(.ECONNABORTED), .posix(.ECONNREFUSED), .tls:
                self.fail(error, category: "connection")
            default:
                break
            }
        case .cancelled:
            self.terminate()
        default:
            break
        }
    }

    func setupDeadlineReached() {
        guard setupDeadline != nil, !isTerminated else { return }
        self.fail(URLError(.timedOut), category: "connection")
    }

    private func cancelSetupDeadline() {
        setupDeadline?.cancel()
        setupDeadline = nil
    }

    private func receiveMessage() {
        guard !isTerminated, !isReceiving else { return }
        self.isReceiving = true
        self.transport.receive { [weak self] result in
            Task { @AIProxyActor [weak self] in self?.didReceive(result) }
        }
    }

    private func didReceive(_ result: Result<OpenAIRealtimeTransport.Frame, Error>) {
        guard !isTerminated else { return }
        self.isReceiving = false
        switch result {
        case .failure(let error):
            self.fail(error, category: "receive")
        case .success(.receiveAgain):
            self.receiveMessage()
        case .success(.closed(let code, let reason, let error)):
            if code == 1000 {
                self.terminate()
            } else {
                let close = OpenAIRealtimeSessionError.closed(code: code, reason: reason, underlyingError: error)
                self.fail(close, category: "receive", code: code)
            }
        case .success(.message(let data)):
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
        self.cancelSetupDeadline()
        self.continuation.finish(throwing: error)
        self.transport.cancel()
    }
}
