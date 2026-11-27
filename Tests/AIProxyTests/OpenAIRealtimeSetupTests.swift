import Foundation
import Network
import Testing
@testable import AIProxy

@AIProxyActor
struct OpenAIRealtimeSetupTests {
    @Test(arguments: [POSIXErrorCode.ENETDOWN, .ENETUNREACH, .EHOSTUNREACH])
    func transientWaitingPreservesSetupAndSubsequentAudioTextDelivery(_ code: POSIXErrorCode) async throws {
        let server = try RealtimeLoopbackServer(upgrade: .deferred)
        defer { server.stop() }
        let connection = makeNativeRealtimeConnection(url: try await server.listening.value())
        let session = OpenAIRealtimeSession(connection: connection, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 2)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        session.start()
        _ = try await server.requestReceived.value()
        // Deterministically exercise Network's documented nonfatal path-waiting
        // state, then continue through a genuine native WebSocket handshake.
        session.handleConnectionState(.waiting(.posix(code)))
        server.acceptDeferredUpgrade()
        try await server.upgraded.value()
        try await server.sendText([RealtimeTestFixtures.text, RealtimeTestFixtures.audio])
        let messages = try await recorder.delivered.value()
        #expect(messages.map(RealtimeMessageRecorder.label) == ["text:Ready", "audio:AQID"])
        let initial = try #require(JSONSerialization.jsonObject(with: Data(try await server.firstClientText.value().utf8)) as? [String: Any])
        #expect(initial["type"] as? String == "session.update")
    }
    @Test
    func successfulSetupIgnoresLateDeadlineAndRemainsFullDuplex() async throws {
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        let connection = makeNativeRealtimeConnection(url: try await server.listening.value())
        let session = OpenAIRealtimeSession(connection: connection, sessionConfiguration: .init())
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 2)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        session.start()
        _ = try await server.firstClientText.value()
        session.setupDeadlineReached()
        try await session.sendMessage(OpenAIRealtimeInputAudioBufferAppend(audio: "AQID"))
        let sent = try #require(JSONSerialization.jsonObject(with: Data(try await server.secondClientText.value().utf8)) as? [String: Any])
        #expect(sent["type"] as? String == "input_audio_buffer.append")
        #expect(sent["audio"] as? String == "AQID")
        try await server.sendText([RealtimeTestFixtures.text, RealtimeTestFixtures.audio])
        #expect(try await recorder.delivered.value().map(RealtimeMessageRecorder.label) == ["text:Ready", "audio:AQID"])
    }

    @Test
    func disconnectWinsAgainstLateWaitingAndDeadline() async throws {
        let server = try RealtimeLoopbackServer(upgrade: .deferred)
        defer { server.stop() }
        let session = OpenAIRealtimeSession(connection: makeNativeRealtimeConnection(url: try await server.listening.value()), sessionConfiguration: .init())
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        session.start()
        _ = try await server.requestReceived.value()
        session.disconnect()
        session.handleConnectionState(.waiting(.posix(.ENETDOWN)))
        session.handleConnectionState(.ready)
        session.setupDeadlineReached()
        try await recorder.finished.value()
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate())
            Issue.record("A late callback must not reopen the session")
        } catch OpenAIRealtimeSessionError.disconnected {}
    }

    @Test(arguments: [false, true])
    func stalledUpgradeAndTransientWaitingEndAtSetupDeadline(_ injectWaiting: Bool) async throws {
        let server = try RealtimeLoopbackServer(upgrade: .deferred)
        defer { server.stop() }
        let session = OpenAIRealtimeSession(connection: makeNativeRealtimeConnection(url: try await server.listening.value()), sessionConfiguration: .init(), setupTimeout: 1)
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        session.start()
        _ = try await server.requestReceived.value()
        if injectWaiting { session.handleConnectionState(.waiting(.posix(.ENETDOWN))) }
        do {
            try await recorder.finished.value()
            Issue.record("Stalled setup must throw its timeout")
        } catch let error as URLError { #expect(error.code == .timedOut) }
        try await server.peerClosed.value()
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate())
            Issue.record("Timed-out setup must reject further sends")
        } catch OpenAIRealtimeSessionError.disconnected {}
    }

    @Test
    func droppingSessionCancelsPendingSetupDeadlineAndConnection() async throws {
        let server = try RealtimeLoopbackServer(upgrade: .deferred)
        defer { server.stop() }
        let connection = makeNativeRealtimeConnection(url: try await server.listening.value())
        var session: OpenAIRealtimeSession? = OpenAIRealtimeSession(connection: connection, sessionConfiguration: .init())
        weak var weakSession = session
        session?.start()
        _ = try await server.requestReceived.value()
        session = nil
        #expect(weakSession == nil)
        try await server.peerClosed.value()
    }
}
