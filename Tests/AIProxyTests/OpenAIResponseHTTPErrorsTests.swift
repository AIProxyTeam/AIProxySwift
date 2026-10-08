#if DEBUG
import Foundation
import Testing
@testable import AIProxy

@Suite("OpenAI Responses HTTP diagnostics")
struct OpenAIResponseHTTPErrorsTests {
    @Test("HTTP-01: creation exposes exact HTTP failure evidence before returning a stream",
          arguments: responseHTTPFailures, ResponseCreation.allCases)
    @AIProxyActor func creationHTTPFailure(failure: ResponseHTTPFailure, creation: ResponseCreation) async throws {
        for proxied in [false, true] {
            let fixture = ControlledHTTPFixture(steps: [.http(
                statusCode: failure.status, body: failure.data, headers: failure.headers
            )])
            defer { fixture.invalidate() }
            let service = fixture.makeOpenAIService(proxied: proxied)
            do {
                try await creation.submit(service)
                Issue.record("HTTP rejection returned a response or a stream")
            } catch let error as AIProxyHTTPError {
                expectHTTPError(error, status: failure.status, data: failure.data, text: failure.text, headers: failure.headers)
            } catch {
                Issue.record("Expected AIProxyHTTPError, received \(error)")
            }
            #expect(fixture.requests.count == 1)
            #expect(fixture.requests.first?.httpMethod == "POST")
            #expect(fixture.requests.first?.url?.path == "/prefix/v1/responses")
        }
    }

    @Test("HTTP-02: background and store choices do not select the error contract",
          arguments: responseFlagChoices, ResponseCreation.allCases)
    @AIProxyActor func backgroundIndependentFailure(flags: ResponseFlags, creation: ResponseCreation) async throws {
        for proxied in [false, true] {
            let data = Data("rate limit\nfixture detail\n".utf8)
            let headers = ["X-Request-ID": "req-flags", "Retry-After": "11"]
            let fixture = ControlledHTTPFixture(steps: [.http(statusCode: 429, body: data, headers: headers)])
            defer { fixture.invalidate() }
            let service = fixture.makeOpenAIService(proxied: proxied)
            let requestBody = OpenAICreateResponseRequestBody(
                input: .text("fixture-input"), model: "fixture-model", store: flags.store,
                stream: false, background: flags.background
            )
            do {
                try await creation.submit(service, requestBody: requestBody)
                Issue.record("Expected HTTP rejection")
            } catch let error as AIProxyHTTPError {
                expectHTTPError(error, status: 429, data: data, text: "rate limit\nfixture detail\n", headers: headers)
            } catch {
                Issue.record("Expected background-independent AIProxyHTTPError, received \(error)")
            }
            #expect(fixture.requests.count == 1)
            let request = try #require(fixture.requests.first)
            let body = try responseRequestJSON(request)
            #expect(body["background"] as? Bool == flags.background)
            #expect(body["store"] as? Bool == flags.store)
            #expect(body["stream"] as? Bool == (creation == .streaming))
            #expect(body["input"] as? String == "fixture-input")
            #expect(body["model"] as? String == "fixture-model")
            #expect(request.timeoutInterval == 17)
            #expect(request.value(forHTTPHeaderField: "X-Example") == "fixture")
            if proxied {
                #expect(request.value(forHTTPHeaderField: "aiproxy-partial-key") == "fixture-partial-key")
                #expect(request.value(forHTTPHeaderField: "aiproxy-client-id") == "fixture-client-id")
                #expect(request.value(forHTTPHeaderField: "aiproxy-devicecheck") == "fixture-device-token")
            } else {
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-api-key")
            }
        }
    }

    @Test("HTTP-01: status 299 keeps successful creation behavior", arguments: [false, true], ResponseCreation.allCases)
    @AIProxyActor func lowerStatusBoundary(proxied: Bool, creation: ResponseCreation) async throws {
        let body = creation == .buffered ? responseCompletedSnapshot : responseCreatedSSE
        let fixture = ControlledHTTPFixture(steps: [.http(statusCode: 299, body: Data(body.utf8))])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        if creation == .buffered {
            let response = try await service.createResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
            #expect(response.id == "resp_http_fixture")
            #expect(response.status == .completed)
        } else {
            let stream = try await service.createStreamingResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
            var events = [OpenAIResponseStreamingEvent]()
            for try await event in stream { events.append(event) }
            #expect(events.count == 1)
            guard case .responseCreated(let created) = try #require(events.first) else {
                Issue.record("Successful 299 stream lost its provider event")
                return
            }
            #expect(created.response.id == "resp_http_fixture")
        }
        #expect(fixture.requests.count == 1)
    }

    @Test("HTTP-01: deprecated forwarding methods expose the same rich error", arguments: [false, true])
    @AIProxyActor func deprecatedForwarding(proxied: Bool) async throws {
        for method in DeprecatedResponseCreation.allCases {
            let data = Data([0x00, 0xff, 0x0a])
            let headers = ["X-Request-ID": "req-deprecated", "Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"]
            let fixture = ControlledHTTPFixture(steps: [.http(statusCode: 429, body: data, headers: headers)])
            defer { fixture.invalidate() }
            let service = fixture.makeOpenAIService(proxied: proxied)
            do {
                try await method.submit(service)
                Issue.record("Deprecated forwarding concealed the HTTP rejection")
            } catch let error as AIProxyHTTPError {
                expectHTTPError(error, status: 429, data: data, text: "", headers: headers)
            } catch {
                Issue.record("Expected AIProxyHTTPError from deprecated forwarding, received \(error)")
            }
            #expect(fixture.requests.count == 1)
            let request = try #require(fixture.requests.first)
            #expect(request.timeoutInterval == (method == .streamingEvents ? 17 : 60))
            #expect(request.value(forHTTPHeaderField: "X-Example") == "fixture")
            #expect(try responseRequestJSON(request)["stream"] as? Bool == (method == .buffered ? nil : true))
        }
    }

    @Test("HTTP-03: creation keeps timeout, connection loss and cancellation errors",
          arguments: [URLError.timedOut, .networkConnectionLost, .cancelled], ResponseCreation.allCases)
    @AIProxyActor func initialTransportFailure(code: URLError.Code, creation: ResponseCreation) async throws {
        for proxied in [false, true] {
            let fixture = ControlledHTTPFixture(steps: [.failure(URLError(code))])
            defer { fixture.invalidate() }
            let service = fixture.makeOpenAIService(proxied: proxied)
            do {
                try await creation.submit(service)
                Issue.record("Expected the original transport failure")
            } catch let error as URLError {
                #expect(error.code == code)
            } catch {
                Issue.record("Transport failure changed type: \(error)")
            }
            #expect(fixture.requests.count == 1)
        }
    }

    @Test("HTTP-03: malformed successful buffered creation keeps DecodingError", arguments: [false, true])
    @AIProxyActor func successfulResponseDecodeFailure(proxied: Bool) async throws {
        let fixture = ControlledHTTPFixture(steps: [.http(body: Data("not JSON\n".utf8))])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        do {
            _ = try await service.createResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
            Issue.record("Expected a DecodingError")
        } catch is DecodingError { }
        catch { Issue.record("Successful response decode failure changed type: \(error)") }
        #expect(fixture.requests.count == 1)
    }

    @Test("HTTP-03: malformed successful SSE keeps the existing skip-and-continue behavior", arguments: [false, true])
    @AIProxyActor func successfulStreamDecodeBehavior(proxied: Bool) async throws {
        let data = Data(("data: {not JSON}\n\n" + responseCreatedSSE).utf8)
        let fixture = ControlledHTTPFixture(steps: [.http(body: data, headers: ["Content-Type": "text/event-stream"])])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let stream = try await service.createStreamingResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
        var events = [OpenAIResponseStreamingEvent]()
        for try await event in stream { events.append(event) }
        #expect(events.count == 1)
        guard case .responseCreated(let created) = try #require(events.first) else {
            Issue.record("Malformed SSE changed the existing decoder behavior")
            return
        }
        #expect(created.response.id == "resp_http_fixture")
        #expect(fixture.requests.count == 1)
    }

    @Test("HTTP-03: cancelling an active submission stops its request without replay",
          arguments: [false, true], ResponseCreation.allCases)
    @AIProxyActor func activeSubmissionCancellation(proxied: Bool, creation: ResponseCreation) async throws {
        let fixture = ControlledHTTPFixture(steps: [.blocked])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let finished = AsyncTestSignal()
        let operation = Task {
            defer { finished.fire() }
            try await creation.submit(service)
        }
        defer { operation.cancel() }
        try await fixture.started.wait()
        operation.cancel()
        try await fixture.stopped.wait()
        try await finished.wait()
        do {
            try await operation.value
            Issue.record("Expected active submission cancellation")
        } catch is CancellationError { }
        catch let error as URLError { #expect(error.code == .cancelled) }
        catch { Issue.record("Cancellation changed type: \(error)") }
        #expect(fixture.requests.count == 1)
        #expect(fixture.requests.first?.httpMethod == "POST")
        #expect(fixture.requests.first?.url?.path == "/prefix/v1/responses")
    }

    @Test("HTTP-03: ordinary streaming keeps an emitted event before transport loss", arguments: [false, true])
    @AIProxyActor func streamLossAfterEvent(proxied: Bool) async throws {
        // Comments flush AsyncBytes without adding provider events.
        let body = Data((responseCreatedSSE + String(repeating: ": fixture flush\n\n", count: 512)).utf8)
        let fixture = ControlledHTTPFixture(steps: [.stream(body: body, headers: ["Content-Type": "text/event-stream"])])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let emitted = AsyncTestSignal()
        let finished = AsyncTestSignal()
        let operation = Task {
            defer { finished.fire() }
            var events = [OpenAIResponseStreamingEvent]()
            var failure: URLError?
            do {
                let stream = try await service.createStreamingResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
                for try await event in stream {
                    events.append(event)
                    emitted.fire()
                }
            } catch let error as URLError {
                failure = error
            } catch {
                Issue.record("Stream transport failure changed type: \(error)")
            }
            return (events, failure)
        }
        defer { operation.cancel() }
        try await emitted.wait()
        fixture.finishStream(error: URLError(.networkConnectionLost))
        try await finished.wait()
        let (events, failure) = await operation.value
        #expect(failure?.code == .networkConnectionLost)
        #expect(events.count == 1)
        guard case .responseCreated(let created) = try #require(events.first) else {
            Issue.record("Transport loss discarded the already emitted event")
            return
        }
        #expect(created.sequenceNumber == 7)
        #expect(created.response.id == "resp_http_fixture")
        #expect(created.response.status == .inProgress)
        #expect(fixture.requests.count == 1)
        #expect(fixture.requests.first?.httpMethod == "POST")
    }

    @Test("HTTP-03: HTTP 200 generation failure and incomplete snapshots remain creation data",
          arguments: [false, true], ["failed", "incomplete"])
    @AIProxyActor func unsuccessfulGenerationIsData(proxied: Bool, status: String) async throws {
        let snapshot = status == "failed" ? responseFailedSnapshot : responseIncompleteSnapshot
        let fixture = ControlledHTTPFixture(steps: [.http(body: Data(snapshot.utf8))])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let response = try await service.createResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
        #expect(response.id == "resp_http_fixture")
        #expect(response.status?.rawValue == status)
        #expect(response.error?.code == (status == "failed" ? "fixture_failure" : nil))
        #expect(response.error?.message == (status == "failed" ? "Fixture generation failed." : nil))
        #expect(response.incompleteDetails?.reason == (status == "incomplete" ? "max_output_tokens" : nil))
        #expect(fixture.requests.count == 1)
    }

    @Test("HTTP-03: successful SSE carries provider failure, incomplete and error events as data", arguments: [false, true])
    @AIProxyActor func generationEventsAreData(proxied: Bool) async throws {
        let body = "data: {\"type\":\"response.failed\",\"sequence_number\":8,\"response\":\(responseFailedSnapshot)}\n\n"
            + "data: {\"type\":\"response.incomplete\",\"sequence_number\":9,\"response\":\(responseIncompleteSnapshot)}\n\n"
            + "data: {\"type\":\"error\",\"sequence_number\":10,\"code\":\"fixture_event_failure\",\"message\":\"Fixture event failed.\",\"param\":\"fixture-param\"}\n\n"
        let fixture = ControlledHTTPFixture(steps: [.http(body: Data(body.utf8), headers: ["Content-Type": "text/event-stream"])])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let stream = try await service.createStreamingResponse(requestBody: .init(model: "fixture-model"), secondsToWait: 17)
        var events = [OpenAIResponseStreamingEvent]()
        for try await event in stream { events.append(event) }
        #expect(events.count == 3)
        guard events.count == 3,
              case .responseFailed(let failed) = events[0],
              case .responseIncomplete(let incomplete) = events[1],
              case .error(let error) = events[2] else {
            Issue.record("Provider generation failures changed from events to thrown errors")
            return
        }
        #expect(failed.sequenceNumber == 8)
        #expect(failed.response.status == .failed)
        #expect(failed.response.error?.code == "fixture_failure")
        #expect(failed.response.error?.message == "Fixture generation failed.")
        #expect(incomplete.sequenceNumber == 9)
        #expect(incomplete.response.status == .incomplete)
        #expect(incomplete.response.incompleteDetails?.reason == "max_output_tokens")
        #expect(error.sequenceNumber == 10)
        #expect(error.code == "fixture_event_failure")
        #expect(error.message == "Fixture event failed.")
        #expect(error.param == "fixture-param")
        #expect(fixture.requests.count == 1)
    }
}

enum ResponseCreation: CaseIterable, Sendable {
    case buffered, streaming

    @AIProxyActor func submit(
        _ service: OpenAIService,
        requestBody: OpenAICreateResponseRequestBody = .init(model: "fixture-model")
    ) async throws {
        switch self {
        case .buffered:
            _ = try await service.createResponse(requestBody: requestBody, secondsToWait: 17, additionalHeaders: ["X-Example": "fixture"])
        case .streaming:
            _ = try await service.createStreamingResponse(requestBody: requestBody, secondsToWait: 17, additionalHeaders: ["X-Example": "fixture"])
        }
    }
}

private enum DeprecatedResponseCreation: CaseIterable, Sendable {
    case buffered, streaming, streamingEvents

    @AIProxyActor func submit(_ service: OpenAIService) async throws {
        let body = OpenAICreateResponseRequestBody(model: "fixture-model")
        let headers = ["X-Example": "fixture"]
        switch self {
        case .buffered:
            _ = try await service.createResponse(requestBody: body, additionalHeaders: headers)
        case .streaming:
            _ = try await service.createStreamingResponse(requestBody: body, additionalHeaders: headers)
        case .streamingEvents:
            _ = try await service.createStreamingResponseEvents(requestBody: body, secondsToWait: 17, additionalHeaders: headers)
        }
    }
}

struct ResponseFlags: Sendable {
    let background: Bool?
    let store: Bool?
}

private let responseFlagChoices = [nil, false, true].flatMap { background in
    [nil, false, true].map { store in ResponseFlags(background: background, store: store) }
}

struct ResponseHTTPFailure: Sendable {
    let status: Int
    let data: Data
    let text: String
    let headers: [String: String]
}

private let responseHTTPFailures: [ResponseHTTPFailure] = [
    .init(status: 300, data: Data("multiple choices".utf8), text: "multiple choices", headers: ["X-Request-ID": "req300"]),
    .init(status: 302, data: Data("redirect body\r\n".utf8), text: "redirect body\r\n", headers: ["X-Request-ID": "req302", "Retry-After": "7"]),
    .init(status: 400, data: Data(#"{"error":{"message":"fixture bad request"}}"#.utf8), text: #"{"error":{"message":"fixture bad request"}}"#, headers: ["X-Request-ID": "req400"]),
    .init(status: 401, data: Data("unauthorized\nfixture detail\n".utf8), text: "unauthorized\nfixture detail\n", headers: ["X-Request-ID": "req401", "Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"]),
    .init(status: 403, data: Data("forbidden ✓".utf8), text: "forbidden ✓", headers: ["X-Request-ID": "req403"]),
    .init(status: 404, data: Data(), text: "", headers: ["X-Request-ID": "req404"]),
    .init(status: 429, data: Data([0x00, 0xff, 0xfe, 0x0a]), text: "", headers: ["X-Request-ID": "req429", "Retry-After": "11"]),
    .init(status: 500, data: Data("first line\nsecond line\n".utf8), text: "first line\nsecond line\n", headers: ["X-Request-ID": "req500"]),
    .init(status: 503, data: Data("unavailable: non-JSON body".utf8), text: "unavailable: non-JSON body", headers: ["X-Request-ID": "req503", "Retry-After": "3"])
]

private func expectHTTPError(_ error: AIProxyHTTPError, status: Int, data: Data, text: String, headers: [String: String]) {
    #expect(error.statusCode == status)
    #expect(error.responseData == data)
    #expect(error.responseBody == text)
    let description = (error as any Error).localizedDescription
    #expect(description.contains(String(status)))
    if !text.isEmpty { #expect(description.contains(text)) }
    for (name, value) in headers { #expect(responseHeader(name, in: error.headers) == value) }
    #expect(responseHeader("Retry-After", in: error.headers) == headers["Retry-After"])
}

private func responseHeader(_ name: String, in headers: [String: String]) -> String? {
    headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
}

private func responseRequestJSON(_ request: URLRequest) throws -> [String: Any] {
    if let body = request.httpBody {
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let count = stream.read(buffer, maxLength: 4096)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private let responseCompletedSnapshot = #"{"id":"resp_http_fixture","status":"completed","output":[],"usage":null}"#
private let responseCreatedSSE = "data: {\"type\":\"response.created\",\"sequence_number\":7,\"response\":{\"id\":\"resp_http_fixture\",\"status\":\"in_progress\",\"output\":[]}}\n\n"
private let responseFailedSnapshot = #"{"id":"resp_http_fixture","status":"failed","output":[],"error":{"code":"fixture_failure","message":"Fixture generation failed."}}"#
private let responseIncompleteSnapshot = #"{"id":"resp_http_fixture","status":"incomplete","output":[],"incomplete_details":{"reason":"max_output_tokens"}}"#
#endif
