#if DEBUG
import Foundation
import XCTest
@testable import AIProxy

final class AIProxyURLRequestCompatibilityTests: XCTestCase {
    @AIProxyActor private static func builder(baseURL: String, proxied: Bool) -> any AIProxyRequestBuilder {
        if proxied {
            return AIProxyProxiedRequestBuilder(
                partialKey: "fixture-partial-key", serviceURL: baseURL, clientID: "fixture-client-id",
                deviceCheckTokenProvider: { _ in "fixture-device-token" }
            )
        }
        return AIProxyDirectRequestBuilder(baseURL: baseURL, unprotectedAuthHeader: (key: "Authorization", value: "Bearer fixture-api-key"))
    }

    #if !targetEnvironment(simulator)
    func testMissingDeviceCheckTokenThrowsBeforeTransportStarts() async throws {
        let fixture = ControlledHTTPFixture(steps: [])
        defer { fixture.invalidate() }
        let service = await fixture.makeOpenAIService(proxied: true, deviceCheckTokenProvider: { clientID in
            XCTAssertEqual(clientID, "fixture-client-id")
            return nil
        })
        let finished = AsyncTestSignal()
        let operation = Task { () -> Result<Void, Error> in
            defer { finished.fire() }
            do {
                _ = try await service.getResponse(responseID: "resp_fixture", secondsToWait: 17)
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        defer { operation.cancel() }
        try await finished.wait()
        switch await operation.value {
        case .failure(AIProxyError.deviceCheckIsUnavailable): break
        case .failure(let error): XCTFail("Unexpected error: \(error)")
        case .success: XCTFail("Expected missing DeviceCheck token to reject the request")
        }
        XCTAssertTrue(fixture.requests.isEmpty)
    }
    #endif

    func testOrdinaryURLsMatchFrozenUpstreamExpectations() async throws {
        // Captured with the unmodified b937591 URLComponents path/query composition.
        // These constants intentionally freeze double slashes and base-query replacement.
        let fixtures = [
            ("https://example.invalid", "/v1/responses", "https://example.invalid/v1/responses"),
            ("https://example.invalid/prefix", "v1/conversations/conv_fixture/items?limit=2&include[]=file_search_call.results", "https://example.invalid/prefix/v1/conversations/conv_fixture/items?limit=2&include%5B%5D=file_search_call.results"),
            ("https://example.invalid/prefix/", "/v1/vector_stores/store_fixture/files", "https://example.invalid/prefix//v1/vector_stores/store_fixture/files"),
            ("https://example.invalid/prefix?base=discard", "/res/v1/web/search?q=hello%20world&count=3", "https://example.invalid/prefix/res/v1/web/search?q=hello%20world&count=3"),
            ("https://example.invalid/", "v1/text-to-speech/voice_fixture/with-timestamps", "https://example.invalid//v1/text-to-speech/voice_fixture/with-timestamps"),
            ("https://example.invalid/prefix?base=discard", "generic?first=a%2Bb&second=a%26b", "https://example.invalid/prefix/generic?first=a+b&second=a%26b"),
            ("https://example.invalid/prefix?base=discard", "generic", "https://example.invalid/prefix/generic")
        ]
        for proxied in [false, true] {
            for (base, route, expected) in fixtures {
                let builder = await Self.builder(baseURL: base, proxied: proxied)
                let request = try await builder.plainGET(path: route, secondsToWait: 17, additionalHeaders: ["X-Example": "fixture"])
                XCTAssertEqual(request.url?.absoluteString, expected)
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertNil(request.httpBody)
                XCTAssertEqual(request.timeoutInterval, 17)
                XCTAssertEqual(request.networkServiceType, .avStreaming)
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Example"), "fixture")
                if proxied {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-partial-key"), "fixture-partial-key")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-client-id"), "fixture-client-id")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-devicecheck"), "fixture-device-token")
                } else { XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-api-key") }
            }
        }
    }

    func testOrdinaryPOSTBodyHeadersAndOverridePolicyRemainUnchanged() async throws {
        for proxied in [false, true] {
            let builder = await Self.builder(baseURL: "https://example.invalid/prefix?base=discard", proxied: proxied)
            let request = try await builder.jsonPOST(
                path: "v1/responses", body: ["input": "fixture-input"], secondsToWait: 17,
                additionalHeaders: ["X-Example": "fixture", "Authorization": "Bearer caller-key", "aiproxy-partial-key": "caller-key"]
            )
            XCTAssertEqual(request.url?.absoluteString, "https://example.invalid/prefix/v1/responses")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
            XCTAssertEqual(body, ["input": "fixture-input"])
            XCTAssertEqual(request.timeoutInterval, 17)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Example"), "fixture")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer caller-key")
            if proxied {
                // Proxied requests continue adding caller values alongside SDK header values.
                XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-partial-key"), "fixture-partial-key,caller-key")
            } else { XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-partial-key"), "caller-key") }
        }
    }

    func testEncodedBaseAndRelativePathsPreserveSuppliedEscapes() async throws {
        let segments = ["a%2Fb", "%41", "%7E", "a%252Fb", "a%3Fb%23c", "a%2fb", "%7e", "%4a"]
        for proxied in [false, true] {
            for segment in segments {
                let builder = await Self.builder(baseURL: "https://example.invalid/\(segment)", proxied: proxied)
                let request = try await builder.plainGET(path: "v1/responses/\(segment)/literal/separators", secondsToWait: 17, additionalHeaders: [:])
                let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
                XCTAssertEqual(components.percentEncodedPath, "/\(segment)/v1/responses/\(segment)/literal/separators")
            }
        }
    }

    func testExistingOpenAIAndMistralMethodsKeepLegacyHTTPError() async throws {
        for proxied in [false, true] {
            for existingMethod in ["openai", "mistral"] {
                let fixture = ControlledHTTPFixture(steps: [.http(statusCode: 429, body: Data("legacy failure\n".utf8), headers: ["Retry-After": "9"])])
                defer { fixture.invalidate() }
                do {
                    if existingMethod == "openai" {
                        let service = await fixture.makeOpenAIService(proxied: proxied)
                        _ = try await service.createResponse(requestBody: .init(input: .text("fixture-input"), model: "fixture-model"), secondsToWait: 17)
                    } else {
                        let builder = await Self.builder(baseURL: fixture.baseURL, proxied: proxied)
                        let service = MistralService(requestBuilder: builder, serviceNetworker: ControlledSessionNetworker(urlSession: fixture.makeSession(proxied: proxied)))
                        _ = try await service.chatCompletionRequest(body: .init(messages: [.user(content: "fixture-input")], model: "fixture-model"), secondsToWait: 17)
                    }
                    XCTFail("Expected legacy HTTP error")
                } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
                    XCTAssertEqual(statusCode, 429)
                    XCTAssertEqual(responseBody, "legacy failure\n")
                } catch { XCTFail("Unexpected error: \(error)") }
                XCTAssertEqual(fixture.requests.count, 1)
                XCTAssertEqual(fixture.requests.first?.httpMethod, "POST")
            }
        }
    }

    func testExistingMetadataDeserializationKeepsLegacyHTTPError() async throws {
        // ElevenLabsProxiedService.ttsRequestWithTimestampsAndMetadata calls this existing
        // default ServiceMixin path. Its hardcoded DeviceCheck/session are inspected separately.
        let fixture = ControlledHTTPFixture(steps: [.http(statusCode: 503, body: Data("legacy metadata failure".utf8), headers: ["Retry-After": "4"])])
        defer { fixture.invalidate() }
        let builder = await Self.builder(baseURL: fixture.baseURL, proxied: true)
        let request = try await builder.jsonPOST(path: "/v1/text-to-speech/voice_fixture/with-timestamps", body: ["text": "fixture-input"], secondsToWait: 17, additionalHeaders: [:])
        let networker = ControlledSessionNetworker(urlSession: fixture.makeSession(proxied: true))
        do {
            let _: AIProxyResponseWithHeaders<ElevenLabsTTSWithTimestampsResponseBody> = try await networker.makeRequestAndDeserializeResponseWithMetadata(request)
            XCTFail("Expected legacy HTTP error")
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            XCTAssertEqual(statusCode, 503)
            XCTAssertEqual(responseBody, "legacy metadata failure")
        } catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(fixture.requests.count, 1)
    }
}
#endif
