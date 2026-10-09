#if DEBUG
import Foundation
import Testing
@testable import AIProxy

@AIProxyActor
struct OpenAIRealtimeSessionFailureTests {
    @Test
    func serializationFailureIsOriginalAndDoesNotSend() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.waitForSend(1)
        let expected = NSError(domain: "RealtimeTests.Serialization", code: 41)
        do {
            try await session.sendMessage(RealtimeThrowingCommand(error: expected))
            Issue.record("Serialization failure must throw")
        } catch {
            #expect(error as NSError === expected)
        }
        #expect(fixture.sent.count == 1)
        #expect(fixture.resumeCount == 1)
        #expect(fixture.cancelCount == 0)
    }

    @Test
    func transportSendFailureIsOriginalAndDoesNotRetry() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.waitForSend(1)
        let expected = NSError(domain: "RealtimeTests.Send", code: 42)
        fixture.sendFailures[2] = expected
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate(eventID: "command_once"))
            Issue.record("Transport send failure must throw")
        } catch {
            #expect(error as NSError === expected)
        }
        #expect(fixture.sent.count == 2)
        #expect(fixture.resumeCount == 1)
        #expect(fixture.cancelCount == 0)
        // A failed command does not impose teardown policy on the caller.
        fixture.deliver(.success(.string(RealtimeTestFixtures.text)))
        try await fixture.waitForReceive(2)
        #expect(fixture.sent.count == 2)
    }

    @Test
    func sendAfterDisconnectThrowsWithoutTouchingTransport() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        try await fixture.waitForSend(1)
        session.disconnect()
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate())
            Issue.record("Disconnected session must reject sends")
        } catch OpenAIRealtimeSessionError.disconnected {
            #expect(fixture.sent.count == 1)
        }
        #expect(fixture.cancelCount == 1)
    }

    @Test(arguments: [false, true])
    func initialConfigurationSendFailureIsRetainedBeforeReceiverAttachment(_ useNSError: Bool) async throws {
        let fixture = RealtimeScriptedTransport()
        let expected = originalFailure(useNSError: useNSError, domain: "RealtimeTests.InitialUpdate", code: 43)
        fixture.sendFailures[1] = expected
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.cancelled.value()
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Initial configuration failure must throw")
        } catch {
            expectOriginalFailure(error, expected)
        }
        #expect(fixture.sent.count == 1)
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
    }

    @Test(arguments: [false, true])
    func receiveFailureIsOriginalAndClosesResourcesOnce(_ useNSError: Bool) async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        let expected = originalFailure(useNSError: useNSError, domain: "RealtimeTests.Receive", code: 44)
        fixture.deliver(.failure(expected))
        do {
            try await recorder.finished.value()
            Issue.record("Receive failure must throw")
        } catch {
            expectOriginalFailure(error, expected)
        }
        try await fixture.cancelled.value()
        session.disconnect()
        session.disconnect()
        #expect(fixture.cancelCount == 1)
        #expect(fixture.resumeCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
    }

    @Test
    func malformedKnownEventThrowsItsDecodingError() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        let bytes = Data(RealtimeTestFixtures.malformedKnownEvent.utf8)
        var expectedError: Error?
        do { _ = try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: bytes) }
        catch { expectedError = error }
        fixture.deliver(.success(.data(bytes)))
        do {
            try await recorder.finished.value()
            Issue.record("Malformed known event must terminate with decoding failure")
        } catch DecodingError.typeMismatch(let type, let context) {
            #expect(ObjectIdentifier(type) == ObjectIdentifier(String.self))
            #expect(context.codingPath.map(\.stringValue) == ["delta"])
            let expectedDecoding = try #require(expectedError as? DecodingError)
            if case DecodingError.typeMismatch(_, let expectedContext) = expectedDecoding {
                #expect(context.debugDescription == expectedContext.debugDescription)
            } else {
                Issue.record("Fixture must independently produce a type mismatch")
            }
        }
        try await fixture.cancelled.value()
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
    }

    @Test(arguments: [false, true])
    func earlyReceiveFailureIsRetainedWithoutAnotherCallback(_ useNSError: Bool) async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let expected = originalFailure(useNSError: useNSError, domain: "RealtimeTests.EarlySetup", code: 45)
        fixture.deliver(.failure(expected))
        try await fixture.cancelled.value()
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Early terminal state must remain observable")
        } catch {
            expectOriginalFailure(error, expected)
        }
        #expect(fixture.receiveCount == 1)
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func localDisconnectFinishesAndIgnoresLateTransportFailure() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        session.disconnect()
        fixture.deliverLate(.failure(NSError(domain: "RealtimeTests.LateCallback", code: 46)))
        session.disconnect()
        try await recorder.finished.value()
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
        #expect(recorder.messages.isEmpty)
    }

    @Test(arguments: [false, true])
    func establishedFailureSurvivesRacingDisconnect(_ useNSError: Bool) async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        let expected = originalFailure(useNSError: useNSError, domain: "RealtimeTests.FirstOutcome", code: 47)
        fixture.deliver(.failure(expected))
        try await fixture.cancelled.value()
        session.disconnect()
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("First terminal failure must survive disconnect")
        } catch {
            expectOriginalFailure(error, expected)
        }
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func cancellationWhileAwaitingNextClosesOnceAndPreservesCancellation() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        fixture.deliver(.success(.string(RealtimeTestFixtures.text)))
        _ = try await recorder.delivered.value()
        try await fixture.waitForReceive(2)
        reader.cancel()
        try await recorder.finished.value()
        try await fixture.cancelled.value()
        #expect(recorder.callerWasCancelled)
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
        #expect(reader.isCancelled)
    }

    @Test
    func taskLifetimeCleanupClosesWhenCancelledDuringEventHandling() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.waitForSend(1)
        let handling = RealtimeTestSignal<Void>()
        let finished = RealtimeTestSignal<Bool>()
        let reader = Task { @AIProxyActor in
            defer {
                session.disconnect()
                finished.succeed(Task.isCancelled)
            }
            for try await _ in session.receiver {
                handling.succeed(())
                // Model cancellable handler work; cancellation ends it, not elapsed time.
                try await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
        defer { reader.cancel() }
        fixture.deliver(.success(.string(RealtimeTestFixtures.text)))
        try await handling.value()
        try await fixture.waitForReceive(2)
        reader.cancel()
        let callerWasCancelled = try await finished.value()
        do {
            try await reader.value
            Issue.record("Handler work must observe cancellation")
        } catch is CancellationError {}
        #expect(callerWasCancelled)
        #expect(reader.isCancelled)
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
        #expect(fixture.resumeCount == 1)
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate())
            Issue.record("Task-lifetime cleanup must reject subsequent sends")
        } catch OpenAIRealtimeSessionError.disconnected {
            #expect(fixture.sent.count == 1)
        }
        session.disconnect()
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func taskLifetimeCleanupClosesWhenEventHandlingReturnsEarly() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.waitForSend(1)
        let finished = RealtimeTestSignal<Void>()
        let reader = Task { @AIProxyActor in
            defer {
                session.disconnect()
                finished.succeed(())
            }
            for try await _ in session.receiver {
                return
            }
            Issue.record("The reader must return while handling its first event")
        }
        defer { reader.cancel() }
        fixture.deliver(.success(.string(RealtimeTestFixtures.text)))
        try await finished.value()
        try await reader.value
        #expect(!reader.isCancelled)
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate())
            Issue.record("Early-return cleanup must reject subsequent sends")
        } catch OpenAIRealtimeSessionError.disconnected {
            #expect(fixture.sent.count == 1)
        }
        session.disconnect()
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func orderedEventsUseOnePendingReceiveAndNeverReconnect() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 6)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        let events = [RealtimeTestFixtures.structuredError, RealtimeTestFixtures.secondError,
                      RealtimeTestFixtures.failedResponse, RealtimeTestFixtures.text,
                      RealtimeTestFixtures.audio, #"{"type":"future.event","opaque":true}"#]
        for (index, event) in events.enumerated() {
            fixture.deliver(.success(.string(event)))
            try await fixture.waitForReceive(index + 2)
        }
        let messages = try await recorder.delivered.value()
        #expect(messages.map(RealtimeMessageRecorder.label) == [
            "error:server_error_1", "error:server_error_2", "response:failed",
            "text:Ready", "audio:AQID", "unknown"
        ])
        #expect(fixture.maximumPendingReceives == 1)
        #expect(fixture.pendingReceivers.count == 1)
        #expect(fixture.receiveCount == 7)
        #expect(fixture.resumeCount == 1)
        #expect(fixture.cancelCount == 0)
        session.disconnect()
        try await recorder.finished.value()
        #expect(recorder.messages.count == 6)
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func pendingInitialSendDoesNotRetainSessionAndCleanupReleasesIt() async throws {
        let fixture = RealtimeScriptedTransport()
        fixture.holdInitialSend = true
        var session: OpenAIRealtimeSession? = fixture.makeSession()
        weak var weakSession = session
        try await fixture.waitForSend(1)
        session = nil
        #expect(weakSession == nil)
        try await fixture.cancelled.value()
        try await fixture.initialSendExited.value()
        #expect(fixture.cancelCount == 1)
        #expect(fixture.pendingReceivers.isEmpty)
        #expect(fixture.sent.count == 1)
    }
}

@AIProxyActor
private final class RealtimeScriptedTransport {
    typealias Callback = @Sendable (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    let cancelled = RealtimeTestSignal<Void>()
    let initialSendExited = RealtimeTestSignal<Void>()
    private let initialSendGate = RealtimeTestSignal<Void>()
    var holdInitialSend = false
    var sendFailures: [Int: Error] = [:]
    private(set) var sent: [URLSessionWebSocketTask.Message] = []
    private(set) var pendingReceivers: [Callback] = []
    private var retiredReceivers: [Callback] = []
    private(set) var receiveCount = 0
    private(set) var maximumPendingReceives = 0
    private(set) var resumeCount = 0
    private(set) var cancelCount = 0
    private var receiveSignals: [Int: RealtimeTestSignal<Void>] = [:]
    private var sendSignals: [Int: RealtimeTestSignal<Void>] = [:]

    func makeSession() -> OpenAIRealtimeSession {
        let transport = OpenAIRealtimeTestTransport(
            send: { [self] message in
                sent.append(message)
                sendSignals[sent.count]?.succeed(())
                if holdInitialSend, sent.count == 1 {
                    defer { initialSendExited.succeed(()) }
                    try await initialSendGate.value()
                }
                if let error = sendFailures[sent.count] { throw error }
            },
            receive: { [self] callback in
                receiveCount += 1
                pendingReceivers.append(callback)
                maximumPendingReceives = max(maximumPendingReceives, pendingReceivers.count)
                receiveSignals[receiveCount]?.succeed(())
            },
            resume: { [self] in resumeCount += 1 },
            cancel: { [self] in
                cancelCount += 1
                retiredReceivers.append(contentsOf: pendingReceivers)
                pendingReceivers.removeAll()
                if holdInitialSend { initialSendGate.fail(CancellationError()) }
                cancelled.succeed(())
            },
            closeCode: { .invalid },
            closeReason: { nil }
        )
        return OpenAIRealtimeSession(testTransport: transport, sessionConfiguration: .init())
    }

    func deliver(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        precondition(!pendingReceivers.isEmpty, "Test must deliver only to a pending receive")
        pendingReceivers.removeFirst()(result)
    }

    func deliverLate(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        for callback in retiredReceivers { callback(result) }
        retiredReceivers.removeAll()
    }

    func waitForReceive(_ count: Int) async throws {
        if receiveCount >= count { return }
        let signal = receiveSignals[count] ?? RealtimeTestSignal<Void>()
        receiveSignals[count] = signal
        try await signal.value()
    }

    func waitForSend(_ count: Int) async throws {
        if sent.count >= count { return }
        let signal = sendSignals[count] ?? RealtimeTestSignal<Void>()
        sendSignals[count] = signal
        try await signal.value()
    }
}

nonisolated private struct RealtimeThrowingCommand: Encodable, Sendable {
    let error: NSError
    func encode(to encoder: Encoder) throws { throw error }
}

nonisolated private final class RealtimeReferenceFailure: Error, @unchecked Sendable {}

nonisolated private func originalFailure(useNSError: Bool, domain: String, code: Int) -> Error {
    if useNSError {
        return NSError(domain: domain, code: code, userInfo: ["fixture_evidence": "original-\(code)"])
    }
    return RealtimeReferenceFailure()
}

nonisolated private func expectOriginalFailure(_ actual: Error, _ expected: Error) {
    if let reference = expected as? RealtimeReferenceFailure {
        #expect(actual as? RealtimeReferenceFailure === reference)
    } else {
        // Throwing streams/continuations copy NSError in the Swift runtime. Its
        // exact domain, code and supplied evidence remain the observable contract.
        let actualNSError = actual as NSError
        let expectedNSError = expected as NSError
        #expect(actualNSError.domain == expectedNSError.domain)
        #expect(actualNSError.code == expectedNSError.code)
        #expect(actualNSError.userInfo["fixture_evidence"] as? String == expectedNSError.userInfo["fixture_evidence"] as? String)
    }
}
#endif
