#if DEBUG
import Foundation
import Testing
@testable import AIProxy

@Suite("OpenAI provider HTTP transport")
struct OpenAIProviderHTTPTests {
    @Test("OA-HTTP-02: JSON, multipart, raw audio and SSE expose rich HTTP failures",
          arguments: providerHTTPFailures, ProviderHTTPOperation.allCases)
    @AIProxyActor func httpFailure(failure: ResponseHTTPFailure, operation: ProviderHTTPOperation) async throws {
        for proxied in [false, true] {
            let fixture = ControlledHTTPFixture(steps: [.http(statusCode: failure.status, body: failure.data, headers: failure.headers)])
            defer { fixture.invalidate() }
            do {
                try await operation.submit(fixture.makeOpenAIService(proxied: proxied))
                Issue.record("HTTP rejection returned a successful value or stream for \(operation)")
            } catch let error as AIProxyHTTPError {
                let streaming = operation == .chatStream || operation == .transcriptionStream
                expectHTTPError(
                    error, status: failure.status,
                    data: streaming ? failure.streamingData : failure.data,
                    text: streaming ? failure.streamingText : failure.text,
                    headers: failure.headers
                )
            } catch {
                Issue.record("Expected provider-wide AIProxyHTTPError for \(operation), received \(error)")
            }
            try expectProviderRequest(fixture, operation: operation, proxied: proxied)
        }
    }

    @Test("OA-HTTP-03: status 299 preserves public values, multipart bytes and ordered SSE",
          arguments: [false, true], ProviderHTTPOperation.allCases)
    @AIProxyActor func successfulBoundary(proxied: Bool, operation: ProviderHTTPOperation) async throws {
        let fixture = ControlledHTTPFixture(steps: [.http(statusCode: 299, body: operation.successData)])
        defer { fixture.invalidate() }
        try await operation.submit(fixture.makeOpenAIService(proxied: proxied), checkSuccess: true)
        try expectProviderRequest(fixture, operation: operation, proxied: proxied)
    }

    @Test("OA-HTTP-03: original timeout, transport loss and cancellation types survive each transport shape",
          arguments: [URLError.timedOut, .networkConnectionLost, .cancelled], ProviderHTTPOperation.transportRepresentatives)
    @AIProxyActor func transportFailure(code: URLError.Code, operation: ProviderHTTPOperation) async throws {
        for proxied in [false, true] {
            let fixture = ControlledHTTPFixture(steps: [.failure(URLError(code))])
            defer { fixture.invalidate() }
            do {
                try await operation.submit(fixture.makeOpenAIService(proxied: proxied))
                Issue.record("Expected the original transport error")
            } catch let error as URLError {
                #expect(error.code == code)
            } catch { Issue.record("Transport failure changed type: \(error)") }
            #expect(fixture.requests.count == 1)
        }
    }

    @Test("OA-HTTP-03: malformed successful JSON retains DecodingError",
          arguments: [false, true], [ProviderHTTPOperation.chat, .imageEdit, .fileUpload, .transcriptionJSON])
    @AIProxyActor func decodingFailure(proxied: Bool, operation: ProviderHTTPOperation) async throws {
        let fixture = ControlledHTTPFixture(steps: [.http(body: Data("not JSON\n".utf8))])
        defer { fixture.invalidate() }
        do {
            try await operation.submit(fixture.makeOpenAIService(proxied: proxied))
            Issue.record("Expected DecodingError from successful HTTP response")
        } catch is DecodingError { }
        catch { Issue.record("Decoding failure changed type: \(error)") }
        #expect(fixture.requests.count == 1)
    }

    @Test("OA-HTTP-03: invalid UTF-8 text transcription keeps its original assertion", arguments: [false, true])
    @AIProxyActor func textDecodingFailure(proxied: Bool) async throws {
        let fixture = ControlledHTTPFixture(steps: [.http(body: Data([0xff, 0xfe]))])
        defer { fixture.invalidate() }
        do {
            try await ProviderHTTPOperation.transcriptionText.submit(fixture.makeOpenAIService(proxied: proxied))
            Issue.record("Expected invalid text transcription to be rejected")
        } catch AIProxyError.assertion(let message) {
            #expect(message == "Could not represent OpenAI's whisper response as string")
        } catch { Issue.record("Text transcription failure changed type: \(error)") }
        #expect(fixture.requests.count == 1)
    }

    @Test("OA-HTTP-03: cancelling an active request stops the selected transport without replay",
          arguments: [false, true], ProviderHTTPOperation.transportRepresentatives)
    @AIProxyActor func activeCancellation(proxied: Bool, operation: ProviderHTTPOperation) async throws {
        let fixture = ControlledHTTPFixture(steps: [.blocked])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let finished = AsyncTestSignal()
        let task = Task {
            defer { finished.fire() }
            try await operation.submit(service)
        }
        defer { task.cancel() }
        try await fixture.started.wait()
        task.cancel()
        try await fixture.stopped.wait()
        try await finished.wait()
        do {
            try await task.value
            Issue.record("Active request cancellation returned success")
        } catch is CancellationError { }
        catch let error as URLError { #expect(error.code == .cancelled) }
        catch { Issue.record("Active cancellation changed type: \(error)") }
        #expect(fixture.requests.count == 1)
    }

    @Test("OA-HTTP-03: established Chat and transcription streams keep emitted events and stop on termination",
          arguments: providerStreamTerminations, [ProviderHTTPOperation.chatStream, .transcriptionStream])
    @AIProxyActor func establishedStreamTermination(termination: ProviderStreamTermination, operation: ProviderHTTPOperation) async throws {
        let proxied = termination.proxied
        let cancel = termination.cancel
        // Comments flush AsyncBytes without adding decoded provider events.
        let body = operation.firstEventData + Data(String(repeating: ": fixture flush\n\n", count: 512).utf8)
        let fixture = ControlledHTTPFixture(steps: [.stream(body: body, headers: ["Content-Type": "text/event-stream"])])
        defer { fixture.invalidate() }
        let service = fixture.makeOpenAIService(proxied: proxied)
        let observed = HTTPEventRecorder()
        let emitted = AsyncTestSignal()
        let finished = AsyncTestSignal()
        let task = Task {
            defer { finished.fire() }
            do {
                try await operation.submit(service, onEvent: { value in
                    observed.append(value)
                    emitted.fire()
                })
                return nil as URLError.Code?
            } catch is CancellationError {
                #expect(cancel)
                return .cancelled
            } catch let error as URLError {
                return error.code
            } catch {
                Issue.record("Established stream failure changed type: \(error)")
                return nil
            }
        }
        defer { task.cancel() }
        try await emitted.wait()
        if cancel {
            task.cancel()
            try await fixture.stopped.wait()
        } else {
            fixture.finishStream(error: URLError(.networkConnectionLost))
        }
        try await finished.wait()
        let failure = await task.value
        if cancel { #expect(failure == nil || failure == .cancelled) }
        else { #expect(failure == .networkConnectionLost) }
        #expect(observed.values == ["first"])
        #expect(fixture.requests.count == 1)
    }

    @Test("OA-HTTP-03: transcription preserves the selected proxy delegate and upload callback")
    @AIProxyActor func transcriptionProgressDelegation() async throws {
        let fixture = ControlledHTTPFixture(steps: [.blocked])
        defer { fixture.invalidate() }
        let session = fixture.makeSession(proxied: true)
        let delegate = try #require(session.delegate as? AIProxyCertificatePinningDelegate)
        let service = fixture.makeOpenAIService(proxied: true, session: session)
        let callbackValues = HTTPProgressRecorder()
        let finished = AsyncTestSignal()
        let task = Task {
            defer { finished.fire() }
            _ = try await service.createTranscriptionRequest(
                body: .init(file: providerUploadBytes, model: "fixture-model"), secondsToWait: 17,
                progressCallback: { callbackValues.append($0) }
            )
        }
        defer { task.cancel() }
        try await fixture.started.wait()
        #expect(delegate.progressCallback != nil)
        // URLProtocol does not exercise upload progress. Drive the installed delegate callback
        // explicitly to verify its forwarding and ratio semantics on the selected session.
        let callbackTask = session.dataTask(with: URLRequest(url: try #require(URL(string: fixture.baseURL))))
        defer { callbackTask.cancel() }
        delegate.urlSession(session, task: callbackTask, didSendBodyData: 2, totalBytesSent: 2, totalBytesExpectedToSend: 8)
        delegate.urlSession(session, task: callbackTask, didSendBodyData: 6, totalBytesSent: 8, totalBytesExpectedToSend: 8)
        delegate.urlSession(session, task: callbackTask, didSendBodyData: 0, totalBytesSent: 0, totalBytesExpectedToSend: 0)
        #expect(callbackValues.values == [0.25, 1.0])
        task.cancel()
        try await fixture.stopped.wait()
        try await finished.wait()
        do {
            try await task.value
            Issue.record("Expected transcription cancellation")
        } catch is CancellationError { }
        catch let error as URLError { #expect(error.code == .cancelled) }
        catch { Issue.record("Transcription cancellation changed type: \(error)") }
        #expect(delegate.progressCallback != nil) // Existing callback persistence is preserved.
        #expect(session.delegate === delegate)
        #expect(fixture.requests.count == 1)
    }
}

enum ProviderHTTPOperation: CaseIterable, Sendable {
    case chat, imageEdit, fileUpload, transcriptionJSON, transcriptionText, speech, chatStream, transcriptionStream

    // JSON, multipart/raw data and both SSE routes need independent cancellation/transport coverage.
    static let transportRepresentatives: [Self] = [.chat, .transcriptionJSON, .speech, .chatStream, .transcriptionStream]

    var path: String {
        switch self {
        case .chat, .chatStream: return "/prefix/v1/chat/completions"
        case .imageEdit: return "/prefix/v1/images/edits"
        case .fileUpload: return "/prefix/v1/files"
        case .transcriptionJSON, .transcriptionText, .transcriptionStream: return "/prefix/v1/audio/transcriptions"
        case .speech: return "/prefix/v1/audio/speech"
        }
    }

    var isMultipart: Bool {
        switch self {
        case .imageEdit, .fileUpload, .transcriptionJSON, .transcriptionText, .transcriptionStream: return true
        default: return false
        }
    }

    var successData: Data {
        switch self {
        case .chat: return Data(#"{"created":42,"model":"fixture-model","choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"fixture answer"}}]}"#.utf8)
        case .imageEdit: return Data(#"{"data":[{"b64_json":"Zml4dHVyZQ==","revised_prompt":"fixture revision"}]}"#.utf8)
        case .fileUpload: return Data(#"{"id":"file_fixture","bytes":4,"filename":"fixture.bin","purpose":"user_data"}"#.utf8)
        case .transcriptionJSON: return Data(#"{"text":"fixture transcript","language":"en","duration":2.5}"#.utf8)
        case .transcriptionText: return Data("fixture transcript ✓\nsecond line\n".utf8)
        case .speech: return Data([0x52, 0x49, 0x46, 0x46, 0x00, 0xff, 0x0a])
        case .chatStream:
            return firstEventData + Data("data: {not JSON}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"second\"},\"index\":0,\"finish_reason\":\"stop\"}],\"id\":\"chat_fixture\"}\n\ndata: [DONE]\n\n".utf8)
        case .transcriptionStream:
            return firstEventData + Data("data: {not JSON}\n\ndata: {\"type\":\"transcript.text.done\",\"text\":\"second\"}\n\ndata: [DONE]\n\n".utf8)
        }
    }

    var firstEventData: Data {
        switch self {
        case .chatStream: return Data("data: {\"choices\":[{\"delta\":{\"content\":\"first\"},\"index\":0}],\"id\":\"chat_fixture\"}\n\n".utf8)
        case .transcriptionStream: return Data("data: {\"type\":\"transcript.text.delta\",\"delta\":\"first\",\"segment_id\":\"segment_fixture\"}\n\n".utf8)
        default: return Data()
        }
    }

    @AIProxyActor func submit(
        _ service: OpenAIService,
        checkSuccess: Bool = false,
        onEvent: (@Sendable (String) -> Void)? = nil
    ) async throws {
        let headers = ["X-Example": "fixture"]
        switch self {
        case .chat:
            let response = try await service.chatCompletionRequest(
                body: .init(model: "fixture-model", messages: [.user(content: .text("fixture-input"))], stream: true),
                secondsToWait: 17, additionalHeaders: headers
            )
            if checkSuccess {
                #expect(response.created == 42)
                #expect(response.model == "fixture-model")
                #expect(response.choices.first?.message.content == "fixture answer")
                #expect(response.choices.first?.finishReason == "stop")
            }
        case .imageEdit:
            let response = try await service.createImageEditRequest(
                body: .init(images: [.png(providerUploadBytes)], prompt: "fixture-input", model: .gptImage1),
                secondsToWait: 17, additionalHeaders: headers
            )
            if checkSuccess {
                #expect(response.data.first?.b64JSON == "Zml4dHVyZQ==")
                #expect(response.data.first?.revisedPrompt == "fixture revision")
            }
        case .fileUpload:
            let response = try await service.uploadFile(contents: providerUploadBytes, name: "fixture.bin", purpose: .userData, secondsToWait: 17, additionalHeaders: headers)
            if checkSuccess {
                #expect(response.id == "file_fixture")
                #expect(response.bytes == 4)
                #expect(response.filename == "fixture.bin")
                #expect(response.purpose == "user_data")
            }
        case .transcriptionJSON, .transcriptionText:
            let response = try await service.createTranscriptionRequest(
                body: .init(file: providerUploadBytes, model: "fixture-model", language: "en", responseFormat: self == .transcriptionText ? "text" : "json", stream: true),
                secondsToWait: 17, additionalHeaders: headers
            )
            if checkSuccess {
                #expect(response.text == (self == .transcriptionText ? "fixture transcript ✓\nsecond line\n" : "fixture transcript"))
                #expect(response.language == (self == .transcriptionText ? nil : "en"))
                #expect(response.duration == (self == .transcriptionText ? nil : 2.5))
            }
        case .speech:
            let response = try await service.createTextToSpeechRequest(body: .init(input: "fixture-input", voice: .alloy, responseFormat: .pcm), secondsToWait: 17, additionalHeaders: headers)
            if checkSuccess { #expect(response == successData) }
        case .chatStream:
            let stream = try await service.streamingChatCompletionRequest(
                body: .init(model: "fixture-model", messages: [.user(content: .text("fixture-input"))], stream: false),
                secondsToWait: 17, additionalHeaders: headers
            )
            if checkSuccess || onEvent != nil {
                var texts = [String]()
                for try await chunk in stream {
                    #expect(chunk.id == "chat_fixture")
                    #expect(chunk.choices.first?.index == 0)
                    let text = try #require(chunk.choices.first?.delta.content)
                    texts.append(text)
                    onEvent?(text)
                }
                if checkSuccess { #expect(texts == ["first", "second"]) }
            }
        case .transcriptionStream:
            let stream = try await service.streamingTranscriptionRequest(
                body: .init(file: providerUploadBytes, model: "fixture-model", responseFormat: "json", stream: false),
                secondsToWait: 17, additionalHeaders: headers
            )
            if checkSuccess || onEvent != nil {
                var texts = [String]()
                for try await event in stream {
                    let text: String
                    switch event {
                    case .textDelta(let delta):
                        #expect(delta.segmentID == "segment_fixture")
                        text = delta.delta
                    case .textDone(let done): text = done.text
                    default:
                        Issue.record("Malformed SSE or DONE marker became an extra transcription event")
                        continue
                    }
                    texts.append(text)
                    onEvent?(text)
                }
                if checkSuccess { #expect(texts == ["first", "second"]) }
            }
        }
    }
}

private func expectProviderRequest(_ fixture: ControlledHTTPFixture, operation: ProviderHTTPOperation, proxied: Bool) throws {
    #expect(fixture.requests.count == 1)
    let request = try #require(fixture.requests.first)
    #expect(request.url?.host == fixture.host)
    #expect(request.url?.path == operation.path)
    #expect(request.httpMethod == "POST")
    #expect(request.timeoutInterval == 17)
    #expect(request.value(forHTTPHeaderField: "X-Example") == "fixture")
    if proxied {
        #expect(request.value(forHTTPHeaderField: "aiproxy-partial-key") == "fixture-partial-key")
        #expect(request.value(forHTTPHeaderField: "aiproxy-client-id") == "fixture-client-id")
        #expect(request.value(forHTTPHeaderField: "aiproxy-devicecheck") == "fixture-device-token")
    } else { #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-api-key") }
    let data = try controlledRequestBody(request)
    if operation.isMultipart {
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
        #expect(data.range(of: providerUploadBytes) != nil)
        let body = String(decoding: data, as: UTF8.self)
        switch operation {
        case .imageEdit:
            #expect(body.contains("name=\"image[]\"; filename=\"tmpfile0\""))
            #expect(body.contains("Content-Type: image/png"))
            #expect(body.contains("name=\"prompt\"\r\n\r\nfixture-input\r\n"))
            #expect(body.contains("name=\"model\"\r\n\r\ngpt-image-1\r\n"))
        case .fileUpload:
            #expect(body.contains("name=\"file\"; filename=\"fixture.bin\""))
            #expect(body.contains("Content-Type: application/octet-stream"))
            #expect(body.contains("name=\"purpose\"\r\n\r\nuser_data\r\n"))
        default:
            #expect(body.contains("name=\"file\"; filename=\"aiproxy.m4a\""))
            #expect(body.contains("Content-Type: audio/mpeg"))
            #expect(body.contains("name=\"model\"\r\n\r\nfixture-model\r\n"))
            #expect(body.contains("name=\"stream\"\r\n\r\n\(operation == .transcriptionStream ? "true" : "false")\r\n"))
            #expect(body.contains("name=\"response_format\"\r\n\r\n\(operation == .transcriptionText ? "text" : "json")\r\n"))
        }
    } else {
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        if operation == .speech {
            #expect(body["input"] as? String == "fixture-input")
            #expect(body["voice"] as? String == "alloy")
            #expect(body["response_format"] as? String == "pcm")
        } else {
            #expect(body["model"] as? String == "fixture-model")
            #expect(body["stream"] as? Bool == (operation == .chatStream))
            let messages = try #require(body["messages"] as? [[String: Any]])
            #expect(messages.first?["content"] as? String == "fixture-input")
            if operation == .chatStream {
                #expect((body["stream_options"] as? [String: Bool])?["include_usage"] == true)
            } else { #expect(body["stream_options"] == nil) }
        }
    }
}

struct ProviderStreamTermination: Sendable {
    let proxied: Bool
    let cancel: Bool
}

private let providerStreamTerminations = [false, true].flatMap { proxied in
    [false, true].map { cancel in ProviderStreamTermination(proxied: proxied, cancel: cancel) }
}

// Reuse the Responses evidence fixtures; that suite covers the remaining 400/401/500/503 cases.
private let providerHTTPFailures = responseHTTPFailures.filter { [300, 302, 403, 404, 429].contains($0.status) }
private let providerUploadBytes = Data([0x66, 0x00, 0xff, 0x0a])

private final class HTTPEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = [String]()
    var values: [String] { lock.withLock { storage } }
    func append(_ value: String) { lock.withLock { storage.append(value) } }
}

private final class HTTPProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = [Double]()
    var values: [Double] { lock.withLock { storage } }
    func append(_ value: Double) { lock.withLock { storage.append(value) } }
}
#endif
