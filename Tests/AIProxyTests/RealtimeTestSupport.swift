import Foundation
import CryptoKit
import Network

/// One-shot test synchronization. The deadline bounds a missing callback; success
/// always comes from an observed event rather than an elapsed positive wait.
nonisolated final class RealtimeTestSignal<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    private var waiter: CheckedContinuation<Value, Error>?
    private var deadline: DispatchWorkItem?

    func resolve(_ result: Result<Value, Error>) {
        let continuation = lock.withLock {
            guard self.result == nil else { return nil as CheckedContinuation<Value, Error>? }
            self.result = result
            deadline?.cancel()
            deadline = nil
            let continuation = waiter
            waiter = nil
            return continuation
        }
        continuation?.resume(with: result)
    }

    func succeed(_ value: Value) { resolve(.success(value)) }
    func fail(_ error: Error) { resolve(.failure(error)) }

    func value(timeout: TimeInterval = 5) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let ready = lock.withLock { () -> Result<Value, Error>? in
                if let result { return result }
                precondition(waiter == nil, "Each test signal has one waiter")
                waiter = continuation
                let item = DispatchWorkItem { [weak self] in
                    self?.fail(RealtimeTestFailure.deadlineExceeded)
                }
                deadline = item
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: item)
                return nil
            }
            if let ready { continuation.resume(with: ready) }
        }
    }
}

nonisolated enum RealtimeTestFailure: Error {
    case deadlineExceeded
    case invalidHandshake
    case unexpectedEnd
}

/// A real TCP peer with a small RFC 6455 handshake/frame implementation. No
/// URLProtocol assumption, TLS override, provider account, or external server.
nonisolated final class RealtimeLoopbackServer: @unchecked Sendable {
    enum Upgrade: Sendable {
        case accept
        case reject(Int)
    }

    let listening = RealtimeTestSignal<URL>()
    let upgraded = RealtimeTestSignal<Void>()
    let acceptedConnections = RealtimeTestSignal<Void>()
    let peerClosed = RealtimeTestSignal<Void>()
    let stoppedListening = RealtimeTestSignal<Void>()
    private let queue = DispatchQueue(label: "AIProxyTests.RealtimeLoopbackServer")
    private let listener: NWListener
    private let upgrade: Upgrade
    private var connection: NWConnection?
    private var handshake = Data()
    private var clientFrames = Data()
    private var isUpgraded = false
    private var sentClose = false
    private var stopped = false
    private(set) var requestText: String?

    init(upgrade: Upgrade = .accept) throws {
        self.upgrade = upgrade
        listener = try NWListener(using: .tcp, on: .any)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard let port = self.listener.port,
                      let url = URL(string: "ws://127.0.0.1:\(port.rawValue)/v1/realtime?model=fixture") else {
                    self.listening.fail(RealtimeTestFailure.invalidHandshake)
                    return
                }
                self.listening.succeed(url)
            case .failed(let error):
                self.fail(error)
            case .cancelled:
                self.stoppedListening.succeed(())
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { connection.cancel(); return }
            guard self.connection == nil else { connection.cancel(); return }
            self.connection = connection
            self.acceptedConnections.succeed(())
            connection.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state { self?.fail(error) }
            }
            connection.start(queue: self.queue)
            self.receive()
        }
        listener.start(queue: queue)
    }

    func sendText(_ messages: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                guard let connection, isUpgraded, !stopped else {
                    continuation.resume(throwing: RealtimeTestFailure.invalidHandshake)
                    return
                }
                let data = messages.reduce(into: Data()) { $0.append(Self.frame(opcode: 1, payload: Data($1.utf8))) }
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                })
            }
        }
    }

    func close(code: UInt16, reason: String = "") async throws {
        var payload = Data([UInt8(code >> 8), UInt8(code & 255)])
        payload.append(contentsOf: reason.utf8)
        let frame = Self.frame(opcode: 8, payload: payload)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                guard let connection, isUpgraded, !stopped else {
                    continuation.resume(throwing: RealtimeTestFailure.invalidHandshake)
                    return
                }
                sentClose = true
                connection.send(content: frame, completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                })
            }
        }
    }

    func stop() {
        queue.async { [self] in
            guard !stopped else { return }
            stopped = true
            connection?.cancel()
            listener.cancel()
        }
    }

    func dropConnection() {
        queue.async { [self] in connection?.cancel() }
    }

    private func fail(_ error: Error) {
        listening.fail(error)
        upgraded.fail(error)
        peerClosed.fail(error)
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            guard let self else { return }
            if let data {
                if self.isUpgraded {
                    self.clientFrames.append(data)
                    self.processClientFrames()
                } else {
                    self.handshake.append(data)
                    self.processHandshake()
                }
            }
            if let error { self.fail(error) }
            if complete {
                self.peerClosed.succeed(())
            } else if error == nil, !self.stopped {
                self.receive()
            }
        }
    }

    private func processHandshake() {
        guard let end = handshake.range(of: Data("\r\n\r\n".utf8)) else { return }
        let request = String(decoding: handshake[..<end.upperBound], as: UTF8.self)
        requestText = request
        guard let keyLine = request.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("sec-websocket-key:")
        }), let key = keyLine.split(separator: ":", maxSplits: 1).last else {
            fail(RealtimeTestFailure.invalidHandshake)
            return
        }
        let response: String
        switch upgrade {
        case .accept:
            let digest = Insecure.SHA1.hash(data: Data((key.trimmingCharacters(in: .whitespaces) + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
            response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(Data(digest).base64EncodedString())\r\n\r\n"
            isUpgraded = true
        case .reject(let status):
            let body = "{\"error\":\"fixture rejection \(status)\"}"
            response = "HTTP/1.1 \(status) Rejected\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nX-Fixture-Request-ID: reject-\(status)\r\nConnection: close\r\n\r\n\(body)"
        }
        connection?.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error { self.fail(error); return }
            self.upgraded.succeed(())
            if case .reject = self.upgrade { self.connection?.cancel() }
        })
        clientFrames = Data(handshake[end.upperBound...])
        handshake.removeAll()
        if isUpgraded { processClientFrames() }
    }

    private func processClientFrames() {
        while clientFrames.count >= 2 {
            let bytes = [UInt8](clientFrames)
            let opcode = bytes[0] & 0x0f
            let masked = bytes[1] & 0x80 != 0
            var length = Int(bytes[1] & 0x7f)
            var offset = 2
            if length == 126 {
                guard bytes.count >= 4 else { return }
                length = Int(bytes[2]) << 8 | Int(bytes[3])
                offset = 4
            } else if length == 127 {
                guard bytes.count >= 10 else { return }
                let wide = bytes[2..<10].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                guard wide < 65_536 else { fail(RealtimeTestFailure.invalidHandshake); return }
                length = Int(wide)
                offset = 10
            }
            let maskLength = masked ? 4 : 0
            guard bytes.count >= offset + maskLength + length else { return }
            var payload = Array(bytes[(offset + maskLength)..<(offset + maskLength + length)])
            if masked {
                for index in payload.indices { payload[index] ^= bytes[offset + index % 4] }
            }
            clientFrames.removeFirst(offset + maskLength + length)
            if opcode == 8 {
                peerClosed.succeed(())
                if !sentClose {
                    sentClose = true
                    connection?.send(content: Self.frame(opcode: 8, payload: Data(payload)), completion: .contentProcessed { [weak self] _ in self?.connection?.cancel() })
                } else {
                    connection?.cancel()
                }
            } else if opcode == 9 {
                connection?.send(content: Self.frame(opcode: 10, payload: Data(payload)), completion: .contentProcessed { _ in })
            }
        }
    }

    private static func frame(opcode: UInt8, payload: Data) -> Data {
        precondition(payload.count <= UInt16.max)
        var data = Data([0x80 | opcode])
        if payload.count < 126 {
            data.append(UInt8(payload.count))
        } else {
            data.append(contentsOf: [126, UInt8(payload.count >> 8), UInt8(payload.count & 255)])
        }
        data.append(payload)
        return data
    }
}
