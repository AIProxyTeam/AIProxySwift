import Foundation
import Testing
@testable import AIProxy

@AIProxyActor
struct OpenAIRealtimeTransportTests {
    @Test(arguments: [1, 2])
    func actualWebSocketContinuesAfterProviderErrors(_ errorCount: Int) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let url = try await server.listening.value()
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let socket = urlSession.webSocketTask(with: url)
        let session = OpenAIRealtimeSession(webSocketTask: socket, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: errorCount + 2)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        var fixtures = [RealtimeTestFixtures.structuredError]
        if errorCount == 2 { fixtures.append(RealtimeTestFixtures.secondError) }
        fixtures.append(contentsOf: [RealtimeTestFixtures.text, RealtimeTestFixtures.audio])
        try await server.sendText(fixtures)
        let messages = try await recorder.delivered.value()
        #expect(messages.map(RealtimeMessageRecorder.label) ==
                (errorCount == 1 ? ["error:server_error_1", "text:Ready", "audio:AQID"] :
                    ["error:server_error_1", "error:server_error_2", "text:Ready", "audio:AQID"]))
        guard case .error(let diagnostic) = messages[0] else {
            Issue.record("Expected the original provider error first")
            return
        }
        #expect(diagnostic.eventID == "server_error_1")
        #expect(diagnostic.error?.eventID == "client_command_1")
        #expect(diagnostic.error?.message == "Unsupported parameter.")
        #expect(diagnostic.error?.type == "invalid_request_error")
        #expect(diagnostic.error?.code == "unknown_parameter")
        #expect(diagnostic.error?.param == "session.unsupported")
        #expect(socket.state == .running)
        try await session.sendMessage(OpenAIRealtimeResponseCreate())
        session.disconnect()
        try await recorder.finished.value()
        #expect(recorder.messages.count == errorCount + 2)
    }

    @Test(arguments: RealtimeTestFixtures.outcomes)
    func actualWebSocketDoesNotTerminateForUnfinishedResponse(_ fixture: RealtimeOutcomeFixture) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let session = OpenAIRealtimeSession(
            webSocketTask: urlSession.webSocketTask(with: try await server.listening.value()),
            sessionConfiguration: .init()
        )
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 2)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        try await server.sendText([fixture.json, RealtimeTestFixtures.text])
        let messages = try await recorder.delivered.value()
        #expect(messages.map(RealtimeMessageRecorder.label) == ["response:\(fixture.status)", "text:Ready"])
        guard case .responseDone(let outcome) = messages[0] else {
            Issue.record("Expected unfinished response")
            return
        }
        #expect(outcome.statusDetails?.type == fixture.status)
        #expect(outcome.statusDetails?.reason == fixture.reason)
        #expect(outcome.statusDetails?.error?.code == fixture.errorCode)
        #expect(outcome.statusDetails?.error?.type == fixture.errorType)
        session.disconnect()
        try await recorder.finished.value()
    }

    @Test
    func actualNormalRemoteCloseFinishesWithoutFailure() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let socket = urlSession.webSocketTask(with: try await server.listening.value())
        let session = OpenAIRealtimeSession(webSocketTask: socket, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        try await server.sendText([RealtimeTestFixtures.text])
        _ = try await recorder.delivered.value()
        try await server.close(code: 1000, reason: "finished")
        try await recorder.finished.value()
        #expect(socket.closeCode.rawValue == 1000)
        #expect(socket.closeReason == Data("finished".utf8))
    }

    @Test
    func actualAbnormalRemoteCloseRetainsCodeReasonAndUnderlyingFailure() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let socket = urlSession.webSocketTask(with: try await server.listening.value())
        let session = OpenAIRealtimeSession(webSocketTask: socket, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        try await server.sendText([RealtimeTestFixtures.text])
        _ = try await recorder.delivered.value()
        try await server.close(code: 1008, reason: "policy fixture")
        do {
            try await recorder.finished.value()
            Issue.record("Abnormal close must throw")
        } catch OpenAIRealtimeSessionError.closed(let code, let reason, let underlyingError) {
            #expect(code == 1008)
            #expect(reason == Data("policy fixture".utf8))
            let original = try #require(underlyingError as NSError?)
            #expect(original.domain == NSPOSIXErrorDomain)
            #expect(original.code == 57)
        }
        #expect(socket.closeCode.rawValue == 1008)
        #expect(socket.closeReason == Data("policy fixture".utf8))
    }

    @Test(arguments: [403, 429, 503])
    func actualRejectedUpgradeExposesOriginalFoundationFailure(_ status: Int) async throws {
        let server = try RealtimeLoopbackServer(upgrade: .reject(status))
        defer { server.stop() }
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let socket = urlSession.webSocketTask(with: try await server.listening.value())
        let session = OpenAIRealtimeSession(webSocketTask: socket, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Rejected upgrade must throw")
        } catch {
            #expect((error as NSError).domain == NSURLErrorDomain)
            #expect((error as NSError).code == URLError.badServerResponse.rawValue)
        }
        let response = try #require(socket.response as? HTTPURLResponse)
        #expect(response.statusCode == status)
        #expect(response.value(forHTTPHeaderField: "X-Fixture-Request-ID") == "reject-\(status)")
        #expect(recorder.messages.isEmpty)
    }

    @Test
    func unavailableEndpointExposesOriginalConnectFailure() async throws {
        let server = try RealtimeLoopbackServer()
        let url = try await server.listening.value()
        server.stop()
        try await server.stoppedListening.value()
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let socket = urlSession.webSocketTask(with: url)
        let session = OpenAIRealtimeSession(webSocketTask: socket, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Unavailable endpoint must throw")
        } catch {
            #expect((error as NSError).domain == NSURLErrorDomain)
            #expect((error as NSError).code == URLError.cannotConnectToHost.rawValue)
        }
        #expect(socket.response == nil)
    }

    @Test
    func abruptSocketLossExposesOriginalFailureWithoutInventedClose() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let urlSession = URLSession(configuration: .ephemeral)
        defer { urlSession.invalidateAndCancel() }
        let socket = urlSession.webSocketTask(with: try await server.listening.value())
        let session = OpenAIRealtimeSession(webSocketTask: socket, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        try await server.sendText([RealtimeTestFixtures.text])
        _ = try await recorder.delivered.value()
        server.dropConnection()
        do {
            try await recorder.finished.value()
            Issue.record("Unexpected socket loss must throw")
        } catch {
            #expect((error as NSError).domain == NSPOSIXErrorDomain)
            #expect((error as NSError).code == 57)
            #expect(error as? OpenAIRealtimeSessionError == nil)
        }
        #expect(socket.closeCode == .invalid)
        #expect(socket.closeReason == nil)
    }
}

@AIProxyActor
final class RealtimeMessageRecorder {
    let delivered = RealtimeTestSignal<[OpenAIRealtimeMessage]>()
    let finished = RealtimeTestSignal<Void>()
    private(set) var messages: [OpenAIRealtimeMessage] = []
    private(set) var callerWasCancelled = false
    private let expectedCount: Int

    init(expectedCount: Int) { self.expectedCount = expectedCount }

    func consume(_ stream: AsyncThrowingStream<OpenAIRealtimeMessage, Error>) -> Task<Void, Never> {
        Task { @AIProxyActor in
            do {
                for try await message in stream {
                    messages.append(message)
                    if messages.count == expectedCount { delivered.succeed(messages) }
                }
                callerWasCancelled = Task.isCancelled
                finished.succeed(())
            } catch {
                callerWasCancelled = Task.isCancelled
                delivered.fail(error)
                finished.fail(error)
            }
        }
    }

    nonisolated static func label(_ message: OpenAIRealtimeMessage) -> String {
        switch message {
        case .error(let payload): return "error:\(payload.eventID ?? "nil")"
        case .responseTextDelta(let payload): return "text:\(payload.delta)"
        case .responseAudioDelta(let payload): return "audio:\(payload.base64Audio)"
        case .responseDone(let payload): return "response:\(payload.status ?? "nil")"
        case .sessionCreated: return "session.created"
        case .sessionUpdated: return "session.updated"
        case .futureProof: return "unknown"
        default: return "other"
        }
    }
}
