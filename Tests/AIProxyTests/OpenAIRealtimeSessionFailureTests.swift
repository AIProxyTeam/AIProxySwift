import Foundation
import Network
import Testing
@testable import AIProxy
#if os(macOS)
import OSLog
#endif

@AIProxyActor
struct OpenAIRealtimeSessionFailureTests {
    #if os(macOS)
    @Test
    func providerSendReceiveAndInitialFailuresProducePrivateDiagnostics() async throws {
        let start = Date().addingTimeInterval(-1)
        let marker = "private-provider-\(UUID().uuidString)"
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.waitForSend(1)
        fixture.deliverMessage("{\"type\":\"error\",\"error\":{\"message\":\"\(marker)\"}}")
        try await fixture.waitForReceive(2)
        fixture.sendFailures[2] = NSError(domain: "RealtimeTests.LogSend", code: 873451)
        do {
            try await session.sendMessage(OpenAIRealtimeResponseCreate())
            Issue.record("Expected send failure")
        } catch {}
        fixture.deliver(.failure(NSError(domain: "RealtimeTests.LogReceive", code: 873452)))
        try await fixture.cancelled.value()
        let startup = RealtimeScriptedTransport()
        startup.sendFailures[1] = NSError(domain: "RealtimeTests.LogInitial", code: 873453)
        let startupSession = startup.makeSession()
        defer { startupSession.disconnect() }
        try await startup.cancelled.value()

        let messages = try await Task.detached { () throws -> [String] in
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: start)
            for _ in 0..<80 {
                let entries = try store.getEntries(at: position, matching: NSPredicate(format: "category == %@", "AIProxy"))
                let messages = entries.compactMap { ($0 as? OSLogEntryLog)?.composedMessage }
                if messages.contains(where: { $0.contains("Realtime provider error:") }),
                   messages.contains(where: { $0.contains("Realtime send failed (code: 873451)") }),
                   messages.contains(where: { $0.contains("Realtime receive failed (code: 873452)") }),
                   messages.contains(where: { $0.contains("Realtime initial send failed (code: 873453)") }) {
                    return messages
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            throw RealtimeTestFailure.deadlineExceeded
        }.value
        #expect(!messages.contains(where: { $0.contains(marker) }))
    }

    @Test
    func malformedEventLogsMetadataWithoutPayload() async throws {
        let start = Date().addingTimeInterval(-1)
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let marker = "private-message-\(UUID().uuidString)"
        let padding = String(repeating: "x", count: 12_345)
        let bytes = Data("{\"type\":\"response.output_text.delta\",\"delta\":123,\"private\":\"\(marker)\",\"padding\":\"\(padding)\"}".utf8)
        fixture.deliver(.success(.message(bytes)))
        try await fixture.cancelled.value()

        let expected = "Realtime decode failed (bytes: \(bytes.count), type: "
        let messages = try await Task.detached { () throws -> [String] in
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: start)
            for _ in 0..<80 {
                let entries = try store.getEntries(at: position, matching: NSPredicate(format: "category == %@", "AIProxy"))
                let messages = entries.compactMap { ($0 as? OSLogEntryLog)?.composedMessage }
                if messages.contains(where: { $0.contains(expected) }) {
                    return messages
                }
                try await Task.sleep(for: .milliseconds(25))
            }
            throw RealtimeTestFailure.deadlineExceeded
        }.value
        let logged = try #require(messages.first(where: { $0.contains(expected) }))
        #expect(logged.contains("DecodingError"))
        #expect(!messages.contains(where: { $0.contains(marker) || $0.contains(padding) }))
    }
    #endif

    @Test
    func initialSessionUpdateSendsReasoningConfiguration() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession(configuration: .init(reasoning: .low, parallelToolCalls: true))
        defer { session.disconnect() }
        try await fixture.waitForSend(1)

        let firstMessage = try #require(fixture.sent.first)
        let json = try JSONSerialization.jsonObject(with: firstMessage)
        let event = try #require(json as? [String: Any])
        #expect(event["type"] as? String == "session.update")
        let configuration = try #require(event["session"] as? [String: Any])
        let reasoning = try #require(configuration["reasoning"] as? [String: Any])
        #expect(reasoning["effort"] as? String == "low")
        #expect(configuration["parallel_tool_calls"] as? Bool == true)
    }

    @Test
    func providerErrorsBeforeReceiverAccessAreDeliveredInOrder() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        for (index, event) in [RealtimeTestFixtures.structuredError, RealtimeTestFixtures.secondError].enumerated() {
            fixture.deliverMessage(event)
            try await fixture.waitForReceive(index + 2)
        }
        let recorder = RealtimeMessageRecorder(expectedCount: 3)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        fixture.deliverMessage(RealtimeTestFixtures.text)
        let messages = try await recorder.delivered.value()
        #expect(messages.map(RealtimeMessageRecorder.label) == ["error:server_error_1", "error:server_error_2", "text:Ready"])
    }

    @Test
    func bufferedErrorDoesNotKeepUnconsumedSessionAlive() async throws {
        let fixture = RealtimeScriptedTransport()
        var session: OpenAIRealtimeSession? = fixture.makeSession()
        weak var weakSession = session
        fixture.deliverMessage(RealtimeTestFixtures.structuredError)
        try await fixture.waitForReceive(2)
        session = nil
        try await fixture.cancelled.value()
        #expect(weakSession == nil)
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func providerErrorBeforeReceiverAccessPrecedesTerminalFailure() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        fixture.deliverMessage(RealtimeTestFixtures.structuredError)
        try await fixture.waitForReceive(2)
        let expected = originalFailure(useNSError: true, domain: "RealtimeTests.EarlyAfterProviderError", code: 49)
        fixture.deliver(.failure(expected))
        try await fixture.cancelled.value()
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Expected the original transport failure")
        } catch {
            expectOriginalFailure(error, expected)
        }
        #expect(recorder.messages.map(RealtimeMessageRecorder.label) == ["error:server_error_1"])
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func earlyProviderErrorPrecedesPendingInitialSendFailure() async throws {
        let fixture = RealtimeScriptedTransport()
        fixture.holdInitialSend = true
        let session = fixture.makeSession()
        defer { session.disconnect() }
        try await fixture.waitForSend(1)
        fixture.deliverMessage(RealtimeTestFixtures.structuredError)
        try await fixture.waitForReceive(2)

        let expected = NSError(domain: "RealtimeTests.PendingInitialSend", code: 51)
        fixture.failInitialSend(expected)
        try await fixture.cancelled.value()
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Expected the original initial send failure")
        } catch {
            expectOriginalFailure(error, expected)
        }
        #expect(recorder.messages.map(RealtimeMessageRecorder.label) == ["error:server_error_1"])
        #expect(fixture.cancelCount == 1)
    }

    @Test
    func failedConnectionDrainsEventsAndCloseAfterInitialSendFails() async throws {
        let fixture = RealtimeScriptedTransport()
        fixture.holdInitialSend = true
        let session = fixture.makeSession()
        defer { session.disconnect() }
        session.handleConnectionState(.ready)
        let socketError = NWError.posix(.ENOTCONN)
        fixture.connectionState = .failed(socketError)
        fixture.failInitialSend(socketError)
        try await fixture.stateRead.value()

        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try #require(fixture.cancelCount == 0)
        fixture.deliverMessage(RealtimeTestFixtures.structuredError)
        try await fixture.waitForReceive(2)
        let reason = Data("fixture".utf8)
        fixture.deliver(.success(.closed(code: 1008, reason: reason, error: socketError)))
        do {
            try await recorder.finished.value()
            Issue.record("Expected the peer's abnormal close")
        } catch OpenAIRealtimeSessionError.closed(let code, let receivedReason, _) {
            #expect(code == 1008)
            #expect(receivedReason == reason)
        }
        #expect(recorder.messages.map(RealtimeMessageRecorder.label) == ["error:server_error_1"])
    }

    @Test
    func earlyProviderErrorRemainsAvailableAfterNormalDisconnect() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        fixture.deliverMessage(RealtimeTestFixtures.structuredError)
        try await fixture.waitForReceive(2)
        session.disconnect()

        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        try await recorder.finished.value()
        #expect(recorder.messages.map(RealtimeMessageRecorder.label) == ["error:server_error_1"])
        #expect(fixture.cancelCount == 1)
    }

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
        fixture.deliverMessage(RealtimeTestFixtures.text)
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

    @Test(arguments: [false, true])
    func confirmedAbnormalCloseRetainsSuppliedUnderlyingError(_ hasCause: Bool) async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let cause = hasCause ? RealtimeReferenceFailure() : nil
        let reason = Data("fixture".utf8)
        fixture.deliver(.success(.closed(code: 1008, reason: reason, error: cause)))
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("Confirmed abnormal close must throw")
        } catch OpenAIRealtimeSessionError.closed(let code, let receivedReason, let underlyingError) {
            #expect(code == 1008)
            #expect(receivedReason == reason)
            if let cause {
                #expect(underlyingError as? RealtimeReferenceFailure === cause)
            } else {
                #expect(underlyingError == nil)
            }
        }
    }

    @Test
    func malformedKnownEventThrowsItsDecodingError() async throws {
        let fixture = RealtimeScriptedTransport()
        let session = fixture.makeSession()
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        let privateMarker = "private-message-marker"
        let bytes = Data("{\"type\":\"response.output_text.delta\",\"delta\":123,\"private\":\"\(privateMarker)\"}".utf8)
        var expectedError: Error?
        do { _ = try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: bytes) }
        catch { expectedError = error }
        fixture.deliver(.success(.message(bytes)))
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
    func establishedFailureSurvivesLaterDisconnect(_ useNSError: Bool) async throws {
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
        fixture.deliverMessage(RealtimeTestFixtures.text)
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
        fixture.deliverMessage(RealtimeTestFixtures.text)
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
        fixture.deliverMessage(RealtimeTestFixtures.text)
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
            fixture.deliverMessage(event)
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
    typealias Callback = OpenAIRealtimeTransport.ReceiveCompletion
    let cancelled = RealtimeTestSignal<Void>()
    let initialSendExited = RealtimeTestSignal<Void>()
    let stateRead = RealtimeTestSignal<Void>()
    var connectionState: NWConnection.State = .ready
    private var pendingSend: OpenAIRealtimeTransport.SendCompletion?
    var holdInitialSend = false
    var sendFailures: [Int: Error] = [:]
    private(set) var sent: [Data] = []
    private(set) var pendingReceivers: [Callback] = []
    private var retiredReceivers: [Callback] = []
    private(set) var receiveCount = 0
    private(set) var maximumPendingReceives = 0
    private(set) var resumeCount = 0
    private(set) var cancelCount = 0
    private var receiveSignals: [Int: RealtimeTestSignal<Void>] = [:]
    private var sendSignals: [Int: RealtimeTestSignal<Void>] = [:]

    func makeSession(configuration: OpenAIRealtimeSessionConfiguration = .init()) -> OpenAIRealtimeSession {
        let transport = OpenAIRealtimeTransport(
            send: { [self] message, completion in
                sent.append(message)
                sendSignals[sent.count]?.succeed(())
                if holdInitialSend, sent.count == 1 {
                    pendingSend = completion
                } else {
                    completion(sendFailures[sent.count])
                }
            },
            receive: { [self] callback in
                receiveCount += 1
                pendingReceivers.append(callback)
                maximumPendingReceives = max(maximumPendingReceives, pendingReceivers.count)
                receiveSignals[receiveCount]?.succeed(())
            },
            state: { [self] in
                stateRead.succeed(())
                return connectionState
            },
            start: { [self] _ in resumeCount += 1 },
            cancel: { [self] in
                cancelCount += 1
                retiredReceivers.append(contentsOf: pendingReceivers)
                pendingReceivers.removeAll()
                if pendingSend != nil { failInitialSend(CancellationError()) }
                cancelled.succeed(())
            }
        )
        let session = OpenAIRealtimeSession(transport: transport, sessionConfiguration: configuration)
        session.start()
        return session
    }

    func deliverMessage(_ text: String) {
        deliver(.success(.message(Data(text.utf8))))
    }

    func deliver(_ result: Result<OpenAIRealtimeTransport.Frame, Error>) {
        precondition(!pendingReceivers.isEmpty, "Test must deliver only to a pending receive")
        pendingReceivers.removeFirst()(result)
    }

    func deliverLate(_ result: Result<OpenAIRealtimeTransport.Frame, Error>) {
        for callback in retiredReceivers { callback(result) }
        retiredReceivers.removeAll()
    }

    func failInitialSend(_ error: Error) {
        pendingSend?(error)
        pendingSend = nil
        initialSendExited.succeed(())
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
