import Foundation
import Network
import Testing
@testable import AIProxy

@AIProxyActor
struct OpenAIRealtimeTransportTests {
    @Test
    func immediateCommandFollowsInitialConfigurationOnWire() async throws {
        let server = try RealtimeLoopbackServer(upgrade: .deferred)
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value(),
                                              configuration: .init(instructions: "fixture instructions"))
        defer { client.session.disconnect() }
        _ = try await server.requestReceived.value()
        let encoded = RealtimeTestSignal<Void>()
        let command = Task { @AIProxyActor in
            try await client.session.sendMessage(ImmediateCommand(encoded: encoded))
        }
        try await encoded.value()
        server.acceptDeferredUpgrade()
        let first = Data(try await server.firstClientText.value().utf8)
        let config = try #require(JSONSerialization.jsonObject(with: first) as? [String: Any])
        #expect(config["type"] as? String == "session.update")
        #expect((config["session"] as? [String: Any])?["instructions"] as? String == "fixture instructions")
        let second = Data(try await server.secondClientText.value().utf8)
        let response = try #require(JSONSerialization.jsonObject(with: second) as? [String: Any])
        #expect(response["type"] as? String == "response.create")
        #expect(response["event_id"] as? String == "fixture_command")
        try await command.value
    }

    @Test(arguments: [false, true])
    func endingSetupReleasesPendingCommand(_ expire: Bool) async throws {
        let server = try RealtimeLoopbackServer(upgrade: .deferred)
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        defer { client.session.disconnect() }
        _ = try await server.requestReceived.value()
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(client.session.receiver)
        defer { reader.cancel() }
        let encoded = RealtimeTestSignal<Void>()
        let sent = RealtimeTestSignal<Void>()
        let command = Task { @AIProxyActor in
            do {
                try await client.session.sendMessage(ImmediateCommand(encoded: encoded))
                sent.succeed(())
            } catch {
                sent.fail(error)
            }
        }
        defer { command.cancel() }
        try await encoded.value()
        if expire { client.session.setupDeadlineReached() }
        else { client.session.disconnect() }
        do {
            try await sent.value()
            Issue.record("A command queued during setup must fail on teardown")
        } catch is NWError {}
        if expire {
            do {
                try await recorder.finished.value()
                Issue.record("The receiver must retain the setup deadline failure")
            } catch let error as URLError { #expect(error.code == .timedOut) }
        } else {
            try await recorder.finished.value()
        }
        try await server.peerClosed.value()
    }

    @Test
    func binaryJSONEventArrivesAndSubsequentTextIsDelivered() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        defer { client.session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 2)
        let reader = recorder.consume(client.session.receiver)
        defer { reader.cancel() }
        _ = try await server.firstClientText.value()
        try await server.sendFrame(opcode: 2, payload: Data(RealtimeTestFixtures.text.utf8))
        try await server.sendText([RealtimeTestFixtures.audio])
        #expect(try await recorder.delivered.value().map(RealtimeMessageRecorder.label) == ["text:Ready", "audio:AQID"])
    }

    @Test
    func fragmentedJSONSurvivesInterleavedPing() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        defer { client.session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(client.session.receiver)
        defer { reader.cancel() }
        _ = try await server.firstClientText.value()
        let json = Data(RealtimeTestFixtures.text.utf8)
        let split = json.count / 2
        try await server.sendFrame(opcode: 1, payload: Data(json.prefix(split)), isFinal: false)
        let ping = Data([0xff])
        try await server.sendFrame(opcode: 9, payload: ping)
        #expect(try await server.clientPong.value() == ping)
        try await server.sendFrame(opcode: 0, payload: Data(json.dropFirst(split)))
        #expect(try await recorder.delivered.value().map(RealtimeMessageRecorder.label) == ["text:Ready"])
    }

    @Test(arguments: [UInt8(1), 2], [Data(), Data("malformed".utf8)])
    func emptyAndMalformedMessagesExposeDecodingError(_ opcode: UInt8, _ bytes: Data) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        defer { client.session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(client.session.receiver)
        defer { reader.cancel() }
        _ = try await server.firstClientText.value()
        try await server.sendFrame(opcode: opcode, payload: bytes)
        do {
            try await recorder.finished.value()
            Issue.record("Malformed payload must throw")
        } catch is DecodingError {}
    }

    @Test(arguments: [1, 2])
    func actualWebSocketContinuesAfterProviderErrors(_ errorCount: Int) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let url = try await server.listening.value()
        let client = makeNativeRealtimeClient(url: url)
        let session = client.session
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
        guard case .ready = client.connection.state else {
            Issue.record("Native WebSocket must remain ready after provider errors")
            return
        }
        try await session.sendMessage(OpenAIRealtimeResponseCreate())
        session.disconnect()
        try await recorder.finished.value()
        #expect(recorder.messages.count == errorCount + 2)
    }

    @Test(arguments: RealtimeTestFixtures.outcomes)
    func actualWebSocketDoesNotTerminateForUnfinishedResponse(_ fixture: RealtimeOutcomeFixture) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        let session = client.session
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
        #expect(outcome.statusDetails?.error?.message == (fixture.status == "failed" ? "The response failed." : nil))
        session.disconnect()
        try await recorder.finished.value()
    }

    @Test
    func actualNormalRemoteCloseFinishesWithoutFailure() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        let session = client.session
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        try await server.sendText([RealtimeTestFixtures.text])
        _ = try await recorder.delivered.value()
        try await server.close(code: 1000, reason: "finished")
        try await recorder.finished.value()
    }

    @Test(arguments: [UInt16(1000), 1008])
    func drainsBufferedEventsBeforeRemoteClose(_ closeCode: UInt16) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        defer { client.session.disconnect() }
        _ = try await server.firstClientText.value()
        let count = 48
        try await server.sendText(Array(repeating: RealtimeTestFixtures.text, count: count),
                                  closingWith: closeCode, reason: "burst")
        let recorder = RealtimeMessageRecorder(expectedCount: count)
        let reader = recorder.consume(client.session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            #expect(closeCode == 1000)
        } catch OpenAIRealtimeSessionError.closed(let code, let reason, _) {
            #expect(closeCode == 1008)
            #expect(code == Int(closeCode))
            #expect(reason == Data("burst".utf8))
        }
        #expect(recorder.messages.map(RealtimeMessageRecorder.label) == Array(repeating: "text:Ready", count: count))
    }

    @Test(arguments: [UInt16(1008), 3000, 4001])
    func actualAbnormalRemoteCloseRetainsSuppliedCodeAndReason(_ closeCode: UInt16) async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        let session = client.session
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await server.upgraded.value()
        try await server.sendText([RealtimeTestFixtures.text])
        _ = try await recorder.delivered.value()
        try await server.close(code: closeCode, reason: "policy fixture")
        do {
            try await recorder.finished.value()
            Issue.record("Abnormal close must throw")
        } catch OpenAIRealtimeSessionError.closed(let code, let reason, let underlyingError) {
            #expect(code == Int(closeCode))
            #expect(reason == Data("policy fixture".utf8))
            if let underlyingError { #expect(underlyingError is NWError) }
        }
    }

    @Test(arguments: [403, 429, 503])
    func actualRejectedUpgradeExposesOriginalNativeFailure(_ status: Int) async throws {
        let server = try RealtimeLoopbackServer(upgrade: .reject(status))
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        let session = client.session
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Rejected upgrade must throw")
        } catch NWError.posix(let code) {
            #expect(code == .ECONNABORTED)
        }
        #expect(recorder.messages.isEmpty)
    }

    @Test
    func unavailableEndpointExposesOriginalConnectFailure() async throws {
        let server = try RealtimeLoopbackServer()
        let url = try await server.listening.value()
        server.stop()
        try await server.stoppedListening.value()
        let client = makeNativeRealtimeClient(url: url)
        let session = client.session
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Unavailable endpoint must throw")
        } catch NWError.posix(let code) {
            #expect(code == .ECONNREFUSED)
        }
    }

    @Test
    func abruptSocketLossExposesOriginalFailureWithoutInventedClose() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        let session = client.session
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
        } catch NWError.posix(let code) {
            #expect(code == .ENODATA || code == .ECONNRESET)
        }
    }

    @Test
    func directFactoryRepliesToPingAndContinuesReceivingTextAndAudio() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let port = try #require(try await server.listening.value().port)
        let service = AIProxy.openAIDirectService(unprotectedAPIKey: "fixture", baseURL: "ws://127.0.0.1:\(port)")
        let session = try await service.realtimeSession(
            model: "fixture", configuration: .init(), logLevel: AIProxyLogLevel.callerDesiredLogLevel
        )
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 2)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        _ = try await server.firstClientText.value()
        let payload = Data([0, 255, 127])
        try await server.sendFrame(opcode: 9, payload: payload)
        #expect(try await server.clientPong.value() == payload)
        try await server.sendFrame(opcode: 10, payload: payload)
        try await server.sendText([RealtimeTestFixtures.text, RealtimeTestFixtures.audio])
        #expect(try await recorder.delivered.value().map(RealtimeMessageRecorder.label) == ["text:Ready", "audio:AQID"])
        session.disconnect()
        try await recorder.finished.value()
    }

    @Test
    func nativeOrdinaryInitialUpdateAndAudioSendRetainPayloads() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let client = makeNativeRealtimeClient(url: try await server.listening.value())
        defer { client.session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(client.session.receiver)
        defer { reader.cancel() }
        let initialJSON = try #require(JSONSerialization.jsonObject(with: Data(try await server.firstClientText.value().utf8)) as? [String: Any])
        #expect(initialJSON["type"] as? String == "session.update")
        let sessionJSON = try #require(initialJSON["session"] as? [String: Any])
        #expect(sessionJSON["type"] as? String == "realtime")
        try await client.session.sendMessage(OpenAIRealtimeInputAudioBufferAppend(audio: "AQID"))
        let command = try #require(JSONSerialization.jsonObject(with: Data(try await server.secondClientText.value().utf8)) as? [String: Any])
        #expect(command["type"] as? String == "input_audio_buffer.append")
        #expect(command["audio"] as? String == "AQID")
        try await server.sendText([RealtimeTestFixtures.audio])
        #expect(try await recorder.delivered.value().map(RealtimeMessageRecorder.label) == ["audio:AQID"])
        client.session.disconnect()
        try await recorder.finished.value()
    }


}

nonisolated private struct ImmediateCommand: Encodable {
    let encoded: RealtimeTestSignal<Void>

    func encode(to encoder: Encoder) throws {
        try OpenAIRealtimeResponseCreate(eventID: "fixture_command").encode(to: encoder)
        encoded.succeed(())
    }
}

/// Creates a native WebSocket session against a local plaintext peer.
@AIProxyActor
private func makeNativeRealtimeClient(url: URL, configuration: OpenAIRealtimeSessionConfiguration = .init()) -> (session: OpenAIRealtimeSession, connection: NWConnection) {
    let connection = makeNativeRealtimeConnection(url: url)
    let session = OpenAIRealtimeSession(connection: connection, sessionConfiguration: configuration)
    session.start()
    return (session, connection)
}

nonisolated func makeNativeRealtimeConnection(url: URL) -> NWConnection {
    let options = NWProtocolWebSocket.Options()
    options.autoReplyPing = true
    let parameters = NWParameters(tls: nil)
    parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
    parameters.serviceClass = .interactiveVoice
    return NWConnection(to: .url(url), using: parameters)
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
