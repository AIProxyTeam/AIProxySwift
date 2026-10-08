#if DEBUG
import Foundation
import Testing
@testable import AIProxy

@Suite("OpenAI background service acceptance")
struct OpenAIBackgroundAcceptanceTests {
    @Test("BM-01.3: snapshot creation preserves background and stream omission", arguments: [false, true])
    @AIProxyActor func backgroundSnapshotCreation(proxied: Bool) async throws {
        let fixture = AcceptanceFixture(scripts: [.success(queuedSnapshot)], proxied: proxied)
        defer { fixture.finish() }
        let response = try await fixture.service.createResponse(
            requestBody: OpenAICreateResponseRequestBody(background: true, model: "fixture-model"),
            secondsToWait: 17,
            additionalHeaders: ["X-Example": "fixture"]
        )
        #expect(response.id == "resp_example")
        #expect(response.status == .queued)
        #expect(response.output.isEmpty)
        #expect(response.usage == nil)
        let requests = fixture.capture.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/prefix/v1/responses")
        #expect(request.timeoutInterval == 17)
        #expect(request.value(forHTTPHeaderField: "X-Example") == "fixture")
        if proxied {
            #expect(request.value(forHTTPHeaderField: "aiproxy-partial-key") == "fixture-partial-key")
            #expect(request.value(forHTTPHeaderField: "aiproxy-client-id") == "fixture-client-id")
            #expect(request.value(forHTTPHeaderField: "aiproxy-devicecheck") == "fixture-device-token")
        } else { #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-api-key") }
        let body = try capturedJSON(request)
        #expect(body["background"] as? Bool == true)
        #expect(body["stream"] == nil)
        #expect(body["store"] == nil)
        #expect(body["model"] as? String == "fixture-model")
    }

    @Test("BM-01.4/BM-02.1-2: service emits queued creation and unchanged raw queue event", arguments: [false, true])
    @AIProxyActor func earlyQueuedEvents(proxied: Bool) async throws {
        let fixture = AcceptanceFixture(scripts: [.success(createdAndRawQueuedSSE, contentType: "text/event-stream")], proxied: proxied)
        defer { fixture.finish() }
        let events = try await fixture.consumeBackgroundStream()
        #expect(events.count == 2)
        guard case .responseCreated(let created) = try #require(events.first) else {
            Issue.record("Queued response.created was not emitted")
            return
        }
        #expect(created.sequenceNumber == 7)
        #expect(created.response.id == "resp_example")
        #expect(created.response.status == .queued)
        #expect(created.response.output.isEmpty)
        #expect(created.response.usage == nil)
        guard case .responseQueued(let queued) = events[1], case .object(let raw) = queued.response else {
            Issue.record("response.queued raw payload changed")
            return
        }
        #expect(queued.sequenceNumber == 8)
        guard case .string(let id) = raw["id"], case .string(let status) = raw["status"],
              case .object(let extensionField) = raw["fixture_extension"], case .bool(let kept) = extensionField["kept"] else {
            Issue.record("Raw queued fields were lost")
            return
        }
        #expect(id == "resp_example")
        #expect(status == "queued")
        #expect(kept)
        let requests = fixture.capture.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        let body = try capturedJSON(request)
        #expect(body["background"] as? Bool == true)
        #expect(body["store"] as? Bool == false)
        #expect(body["stream"] as? Bool == true)
    }

    @Test("BM-02.3: EOF or transport loss invents no completion and starts no recovery", arguments: [false, true], [false, true])
    @AIProxyActor func unfinishedStream(withID: Bool, networkError: Bool) async throws {
        for proxied in [false, true] {
            let body = withID ? createdSSE : "event: incomplete\ndata: {not-json}\n\n"
            let fixture = AcceptanceFixture(scripts: [networkError ? .stream(body: Data((body + sseTransportPadding).utf8), headers: ["Content-Type": "text/event-stream"]) : .success(body, contentType: "text/event-stream")], proxied: proxied)
            let emittedID = AsyncTestSignal()
            let release = networkError ? releaseStreamLoss(fixture, afterID: withID ? emittedID : nil) : nil
            defer { release?.cancel() }
            defer { fixture.finish() }
            var events = [OpenAIResponseStreamingEvent]()
            var receivedError: URLError?
            do {
                let stream = try await fixture.backgroundStream()
                for try await event in stream {
                    events.append(event)
                    emittedID.fire()
                }
            } catch let error as URLError {
                receivedError = error
            }
            await release?.value
            if networkError { #expect(receivedError?.code == .networkConnectionLost) }
            else { #expect(receivedError == nil) }
            #expect(events.count == (withID ? 1 : 0))
            if withID {
                guard case .responseCreated(let created) = try #require(events.first) else {
                    Issue.record("Queued provider identity disappeared")
                    return
                }
                #expect(created.response.id == "resp_example")
                #expect(created.response.status == .queued)
                #expect(created.sequenceNumber == 7)
            }
            #expect(events.allSatisfy { if case .responseCompleted = $0 { return false }; return true })
            #expect(fixture.capture.requests.count == 1)
            #expect(fixture.capture.requests.allSatisfy { $0.httpMethod == "POST" && $0.url?.path == "/prefix/v1/responses" })
        }
    }

    @Test("BM-03.3: caller-requested GET recovers snapshot after queued stream ends", arguments: [false, true])
    @AIProxyActor func explicitRecovery(networkError: Bool) async throws {
        for proxied in [false, true] {
            let fixture = AcceptanceFixture(scripts: [
                networkError ? .stream(body: Data((createdSSE + sseTransportPadding).utf8), headers: ["Content-Type": "text/event-stream"]) : .success(createdSSE, contentType: "text/event-stream"),
                .success(completedSnapshot, headers: ["X-Request-ID": "fixture-recovery"])
            ], proxied: proxied)
            let emittedID = AsyncTestSignal()
            let release = networkError ? releaseStreamLoss(fixture, afterID: emittedID) : nil
            defer { release?.cancel() }
            defer { fixture.finish() }
            var retainedID: String?
            do {
                let stream = try await fixture.backgroundStream()
                for try await event in stream {
                    guard case .responseCreated(let created) = event else {
                        Issue.record("Unrequested terminal event was emitted")
                        continue
                    }
                    retainedID = created.response.id
                    emittedID.fire()
                }
            } catch let error as URLError {
                #expect(networkError)
                #expect(error.code == .networkConnectionLost)
            }
            await release?.value
            #expect(fixture.capture.requests.count == 1)
            let id = try #require(retainedID)
            let result = try await fixture.service.getResponse(responseID: id, secondsToWait: 17)
            let response = result.body
            #expect(result.headers.first { $0.key.lowercased() == "x-request-id" }?.value == "fixture-recovery")
            #expect(response.id == id)
            #expect(response.status == .completed)
            #expect(response.outputText == "firstsecond")
            #expect(response.usage?.totalTokens == 13)
            let requests = fixture.capture.requests
            #expect(requests.count == 2)
            #expect(requests.map(\.httpMethod) == ["POST", "GET"])
            #expect(requests.map { $0.url?.path } == ["/prefix/v1/responses", "/prefix/v1/responses/resp_example"])
            #expect(requests.last?.httpBody == nil)
        }
    }

    @Test("BM-05.4: actual service stream preserves completed refusal explanation", arguments: [false, true])
    @AIProxyActor func completedRefusalThroughStream(proxied: Bool) async throws {
        let fixture = AcceptanceFixture(scripts: [.success(
            "data: {\"type\":\"response.completed\",\"sequence_number\":9,\"response\":\(refusalSnapshot)}\n\n",
            contentType: "text/event-stream"
        )], proxied: proxied)
        defer { fixture.finish() }
        let events = try await fixture.consumeBackgroundStream()
        #expect(events.count == 1)
        guard case .responseCompleted(let completed) = try #require(events.first) else {
            Issue.record("Completed fixture was not emitted")
            return
        }
        #expect(completed.sequenceNumber == 9)
        #expect(completed.response.id == "resp_refusal")
        #expect(completed.response.status == .completed)
        #expect(completed.response.outputText.isEmpty)
        guard case .message(let message) = try #require(completed.response.output.first),
              case .refusal(let explanation) = try #require(message.content.first) else {
            Issue.record("Refusal content was not preserved")
            return
        }
        #expect(explanation == "Fixture refusal explanation.")
        #expect(fixture.capture.requests.count == 1)
    }
    @Test("BM-05.2: HTTP 200 failure, incomplete and cancellation are inspectable data", arguments: ["failed", "incomplete", "cancelled"])
    @AIProxyActor func terminalSnapshotDetails(status: String) async throws {
        for proxied in [false, true] {
            let details = if status == "failed" {
                ",\"error\":{\"code\":\"fixture_failure\",\"message\":\"Fixture generation failed.\"}"
            } else if status == "incomplete" {
                ",\"incomplete_details\":{\"reason\":\"max_output_tokens\"}"
            } else { "" }
            let json = "{\"id\":\"resp_example\",\"status\":\"\(status)\",\"output\":[]\(details)}"
            let fixture = AcceptanceFixture(scripts: [.success(json)], proxied: proxied)
            defer { fixture.finish() }
            let response = try await fixture.service.getResponse(responseID: "resp_example", secondsToWait: 17).body
            #expect(response.id == "resp_example")
            #expect(response.status?.rawValue == status)
            #expect(response.error?.code == (status == "failed" ? "fixture_failure" : nil))
            #expect(response.error?.message == (status == "failed" ? "Fixture generation failed." : nil))
            #expect(response.incompleteDetails?.reason == (status == "incomplete" ? "max_output_tokens" : nil))
            #expect(fixture.capture.requests.count == 1)
            #expect(fixture.capture.requests.first?.httpMethod == "GET")
        }
    }

    @Test("BM-05.3: retrieval preserves supported output order, source, annotation and usage", arguments: [false, true])
    @AIProxyActor func supportedOutputThroughRetrieval(proxied: Bool) async throws {
        let fixture = AcceptanceFixture(scripts: [.success(richCompletedSnapshot)], proxied: proxied)
        defer { fixture.finish() }
        let response = try await fixture.service.getResponse(responseID: "resp_example", secondsToWait: 17).body
        #expect(response.status == .completed)
        #expect(response.outputText == "firstsecond") // Immutable upstream outputText uses joined().
        #expect(response.output.count == 4)
        guard case .reasoning(let reasoning) = response.output[0],
              case .webSearchCall(let search) = response.output[1],
              case .message(let first) = response.output[2],
              case .message(let second) = response.output[3],
              case .outputText(let text) = try #require(first.content.first),
              case .urlCitation(let citation) = try #require(text.annotations?.first) else {
            Issue.record("Supported output fields or order changed")
            return
        }
        #expect(reasoning.id == "rs_fixture")
        #expect(reasoning.summary?.first?.text == "Fixture summary.")
        #expect(search.action?.sources?.first?.url == "https://example.com/source")
        #expect(first.id == "msg_first")
        #expect(second.id == "msg_second")
        #expect(citation.url.absoluteString == "https://example.com/source")
        #expect(citation.startIndex == 0)
        #expect(citation.endIndex == 5)
        #expect(response.usage?.inputTokens == 5)
        #expect(response.usage?.inputTokensDetails?.cachedTokens == 2)
        #expect(response.usage?.outputTokens == 8)
        #expect(response.usage?.outputTokensDetails?.reasoningTokens == 3)
        #expect(response.usage?.totalTokens == 13)
        #expect(fixture.capture.requests.count == 1)
    }

}

private let queuedSnapshot = #"{"id":"resp_example","status":"queued","output":[],"usage":null}"#
private let createdSSE = "data: {\"type\":\"response.created\",\"sequence_number\":7,\"response\":\(queuedSnapshot)}\n\n"
private let createdAndRawQueuedSSE = createdSSE + #"data: {"type":"response.queued","sequence_number":8,"response":{"id":"resp_example","status":"queued","fixture_extension":{"kept":true}}}"# + "\n\n"
private let completedSnapshot = #"{"id":"resp_example","status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"first","annotations":[]}]},{"type":"message","content":[{"type":"output_text","text":"second","annotations":[]}]}],"usage":{"input_tokens":5,"output_tokens":8,"total_tokens":13}}"#
private let refusalSnapshot = #"{"id":"resp_refusal","status":"completed","output":[{"type":"message","content":[{"type":"refusal","refusal":"Fixture refusal explanation."}]}],"usage":null}"#

private func capturedJSON(_ request: URLRequest) throws -> [String: Any] {
    let data: Data
    if let body = request.httpBody { data = body }
    else if let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var buffered = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 4096)
            if count <= 0 { break }
            buffered.append(buffer, count: count)
        }
        data = buffered
    } else { throw AcceptanceFailure.missingRequestBody }
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private enum AcceptanceFailure: Error { case missingRequestBody }

private extension ControlledHTTPFixture.Step {
    static func success(_ text: String, contentType: String = "application/json", headers: [String: String] = [:]) -> Self {
        var headers = headers
        headers["Content-Type"] = contentType
        return .http(body: Data(text.utf8), headers: headers)
    }

}

@AIProxyActor private struct AcceptanceFixture {
    let capture: ControlledHTTPFixture
    let service: OpenAIService

    init(scripts: [ControlledHTTPFixture.Step], proxied: Bool = false) {
        capture = ControlledHTTPFixture(steps: scripts)
        service = capture.makeOpenAIService(proxied: proxied)
    }
    func finish() { capture.invalidate() }
    func backgroundStream() async throws -> AsyncThrowingStream<OpenAIResponseStreamingEvent, Error> {
        try await service.createStreamingResponse(
            requestBody: OpenAICreateResponseRequestBody(background: true, model: "fixture-model", store: false, stream: false),
            secondsToWait: 17
        )
    }
    func consumeBackgroundStream() async throws -> [OpenAIResponseStreamingEvent] {
        let stream = try await backgroundStream()
        var events = [OpenAIResponseStreamingEvent]()
        for try await event in stream { events.append(event) }
        return events
    }
}

/// A loss is injected only after its stated prerequisite is observable, with a bounded watchdog.
@AIProxyActor private func releaseStreamLoss(_ fixture: AcceptanceFixture, afterID signal: AsyncTestSignal?) -> Task<Void, Never> {
    Task {
        do {
            if let signal { try await signal.wait(timeout: 3) }
            else { try await fixture.capture.streamReady.wait(timeout: 3) }
            fixture.capture.finishStream(error: URLError(.networkConnectionLost))
        } catch {
            fixture.capture.finishStream(error: URLError(.timedOut))
        }
    }
}

private let richCompletedSnapshot = #"{"id":"resp_example","status":"completed","output":[{"type":"reasoning","id":"rs_fixture","summary":[{"type":"summary_text","text":"Fixture summary."}]},{"type":"web_search_call","id":"ws_fixture","status":"completed","action":{"type":"search","query":"fixture","sources":[{"type":"url","url":"https://example.com/source"}]}},{"type":"message","id":"msg_first","content":[{"type":"output_text","text":"first","annotations":[{"type":"url_citation","start_index":0,"end_index":5,"url":"https://example.com/source","title":"Fixture source"}]}]},{"type":"message","id":"msg_second","content":[{"type":"output_text","text":"second","annotations":[]}]}],"usage":{"input_tokens":5,"input_tokens_details":{"cached_tokens":2},"output_tokens":8,"output_tokens_details":{"reasoning_tokens":3},"total_tokens":13}}"#

// SSE comments supply enough bytes to exercise incremental URLSession.AsyncBytes delivery.
private let sseTransportPadding = String(repeating: ": fixture flush\n\n", count: 512)
#endif
