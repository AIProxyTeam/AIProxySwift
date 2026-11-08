//
//  RealtimeSession.swift
//
//
//  Created by Lou Zell on 11/28/24.
//

import AVFoundation
import Foundation

nonisolated private let kWebsocketDisconnectedErrorCode = 57
nonisolated private let kWebsocketDisconnectedEarlyThreshold: TimeInterval = 3

@AIProxyActor open class OpenAIRealtimeSession {
    private var isTearingDown = false
    private let webSocketTask: URLSessionWebSocketTask
    private var continuation: AsyncStream<OpenAIRealtimeMessage>.Continuation?
    private let setupTime = Date()
    let sessionConfiguration: OpenAIRealtimeSessionConfiguration
    private let initialSessionUpdate: OpenAIRealtimeSessionUpdate

    init(
        webSocketTask: URLSessionWebSocketTask,
        sessionConfiguration: OpenAIRealtimeSessionConfiguration
    ) {
        self.webSocketTask = webSocketTask
        self.sessionConfiguration = sessionConfiguration
        self.initialSessionUpdate = OpenAIRealtimeSessionUpdate(session: sessionConfiguration)

        Task {
            await self.sendMessage(self.initialSessionUpdate)
        }
        self.webSocketTask.resume()
        self.receiveMessage()
    }

    deinit {
        logIf(.debug)?.debug("OpenAIRealtimeSession is being freed")
    }

    /// Messages sent from OpenAI are published on this receiver as they arrive
    public var receiver: AsyncStream<OpenAIRealtimeMessage> {
        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    /// Sends a message through the websocket connection
    public func sendMessage(_ encodable: Encodable) async {
        guard !self.isTearingDown else {
            logIf(.debug)?.debug("Ignoring ws sendMessage. The RT session is tearing down.")
            return
        }
        do {
            let wsMessage = URLSessionWebSocketTask.Message.string(try encodable.serialize())
            try await self.webSocketTask.send(wsMessage)
        } catch {
            logIf(.error)?.error("Could not send message to OpenAI: \(error.localizedDescription)")
        }
    }

    /// Close the websocket connection
    public func disconnect() {
        self.isTearingDown = true
        self.continuation?.finish()
        self.continuation = nil
        self.webSocketTask.cancel()
    }

    /// Tells the websocket task to receive a new message
    private func receiveMessage() {
        self.webSocketTask.receive { result in
            switch result {
            case .failure(let error as NSError):
                Task {
                    await self.didReceiveWebSocketError(error)
                }
            case .success(let message):
                Task {
                    await self.didReceiveWebSocketMessage(message)
                }
            }
        }
    }

    /// Handles socket errors. We disconnect on all errors.
    private func didReceiveWebSocketError(_ error: NSError) {
        guard !isTearingDown else {
            return
        }

        switch error.code {
        case kWebsocketDisconnectedErrorCode:
            let disconnectedEarly = Date().timeIntervalSince(setupTime) <= kWebsocketDisconnectedEarlyThreshold
            if disconnectedEarly {
                logIf(.warning)?.warning("AIProxy: websocket disconnected immediately. Check that you've followed the DeviceCheck integration guide at https://www.aiproxy.com/docs/integration-guide.html")
            } else {
                logIf(.debug)?.debug("AIProxy: websocket disconnected normally")
            }
        default:
            logIf(.error)?.error("Received ws error: \(error.localizedDescription)")
        }

        self.disconnect()
    }

    /// Handles received websocket messages
    private func didReceiveWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8) {
                self.didReceiveWebSocketData(data)
            }
        case .data(let data):
            self.didReceiveWebSocketData(data)
        @unknown default:
            logIf(.error)?.error("Received an unknown websocket message format")
            self.disconnect()
        }
    }

    private func didReceiveWebSocketData(_ data: Data) {
        guard !self.isTearingDown else {
            // The caller already initiated disconnect,
            // don't send any more messages back to the caller
            return
        }

        do {
            let message = try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: data)
            self.continuation?.yield(message)
            if case .error(let errorEvent) = message {
                logIf(.error)?.error("Received realtime error event from OpenAI: \(errorEvent.errorBody ?? "no body")")
                return
            }
            if !self.isTearingDown {
                self.receiveMessage()
            }
        } catch {
            let strMessage = String(data: data, encoding: .utf8) ?? "unknown"
            logIf(.error)?.error("Received websocket data that we don't understand: \(strMessage)")
            self.disconnect()
        }
    }
}
