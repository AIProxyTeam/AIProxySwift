#if DEBUG
import Foundation
import XCTest
@testable import AIProxy

final class OpenAIResponseRetrievalTests: XCTestCase {
    private func snapshot(status: String = "completed") -> Data {
        Data("{\"id\":\"resp_fixture\",\"status\":\"\(status)\",\"output\":[],\"usage\":null}".utf8)
    }

    private static func retrieve(
        service: OpenAIService,
        responseID: String = "resp_fixture",
        include: [OpenAIInclude]? = nil,
        headers: [String: String] = [:]
    ) async throws -> AIProxyResponseWithHeaders<OpenAIResponse> {
        try await service.getResponse(
            responseID: responseID,
            include: include,
            secondsToWait: 17,
            additionalHeaders: headers
        )
    }

    private func header(_ name: String, in headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    func testRetrievalReturnsOneSnapshotAndHeadersWithoutPolling() async throws {
        for proxied in [false, true] {
            for status in ["queued", "in_progress", "completed"] {
                let fixture = ControlledHTTPFixture(steps: [.http(body: snapshot(status: status), headers: ["X-Request-ID": "request-fixture"])])
                defer { fixture.invalidate() }
                let service = await fixture.makeOpenAIService(proxied: proxied)
                let response = try await Self.retrieve(service: service)
                XCTAssertEqual(response.body.id, "resp_fixture")
                XCTAssertEqual(response.body.status?.rawValue, status)
                XCTAssertTrue(response.body.output.isEmpty)
                XCTAssertNil(response.body.usage)
                XCTAssertEqual(header("x-request-id", in: response.headers), "request-fixture")
                XCTAssertEqual(fixture.requests.count, 1)
                let request = try XCTUnwrap(fixture.requests.first)
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertNil(request.httpBody)
                XCTAssertNil(request.httpBodyStream)
            }
        }
    }

    func testRealBuildersPreserveAllRequestFormatsAndConfiguration() async throws {
        let formats: [(OpenAIRequestFormat, String, [URLQueryItem])] = [
            (.standard, "/prefix/v1/responses/resp_fixture", []),
            (.noVersionPrefix, "/prefix/responses/resp_fixture", []),
            (.azureDeployment(apiVersion: "fixture-version"), "/prefix/responses/resp_fixture", [.init(name: "api-version", value: "fixture-version")])
        ]
        for proxied in [false, true] {
            for (format, path, query) in formats {
                let fixture = ControlledHTTPFixture(steps: [.http(body: snapshot())])
                defer { fixture.invalidate() }
                let service = await fixture.makeOpenAIService(proxied: proxied, requestFormat: format)
                _ = try await Self.retrieve(service: service, headers: ["X-Example": "fixture"])
                let request = try XCTUnwrap(fixture.requests.first)
                let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
                XCTAssertEqual(components.percentEncodedPath, path)
                XCTAssertEqual(components.queryItems ?? [], query)
                XCTAssertNil(components.fragment)
                XCTAssertEqual(request.timeoutInterval, 17)
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Example"), "fixture")
                XCTAssertEqual(request.networkServiceType, .avStreaming)
                if proxied {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-partial-key"), "fixture-partial-key")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-client-id"), "fixture-client-id")
                    XCTAssertEqual(request.value(forHTTPHeaderField: "aiproxy-devicecheck"), "fixture-device-token")
                    XCTAssertNotNil(request.value(forHTTPHeaderField: "aiproxy-metadata"))
                    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                } else {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-api-key")
                }
                XCTAssertEqual(fixture.requests.count, 1)
            }
            let fixture = ControlledHTTPFixture(steps: [])
            defer { fixture.invalidate() }
            let session = fixture.makeSession(proxied: proxied)
            if proxied { XCTAssertTrue(session.delegate is AIProxyCertificatePinningDelegate) }
            else { XCTAssertTrue(session.delegate is DirectURLSessionDataDelegate) }
        }
    }

    func testOpaqueResponseIDsStayOneEncodedSegment() async throws {
        let ids = [
            ("resp_a/b", "resp_a%2Fb"), ("resp_a?b#c", "resp_a%3Fb%23c"),
            ("resp_a%2Fb", "resp_a%252Fb"), ("resp_a b", "resp_a%20b"),
            ("resp_✓", "resp_%E2%9C%93"), ("resp_a+b", "resp_a%2Bb"),
            ("resp_a&b", "resp_a%26b")
        ]
        for proxied in [false, true] {
            let formats: [(OpenAIRequestFormat, String)] = [
                (.standard, "/prefix/v1/responses/"),
                (.noVersionPrefix, "/prefix/responses/"),
                (.azureDeployment(apiVersion: "fixture-version"), "/prefix/responses/")
            ]
            for (format, prefix) in formats {
                for (raw, encoded) in ids {
                    let fixture = ControlledHTTPFixture(steps: [.http(body: snapshot())])
                    defer { fixture.invalidate() }
                    let service = await fixture.makeOpenAIService(proxied: proxied, requestFormat: format)
                    _ = try await Self.retrieve(service: service, responseID: raw)
                    let url = try XCTUnwrap(fixture.requests.first?.url)
                    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
                    XCTAssertEqual(components.percentEncodedPath, prefix + encoded)
                    if case .azureDeployment = format {
                        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "api-version", value: "fixture-version")])
                    } else { XCTAssertNil(components.query) }
                    XCTAssertNil(components.fragment)
                    XCTAssertEqual(fixture.requests.count, 1)
                }
            }
        }
    }

    func testInvalidResponseIDsFailBeforeNetworking() async throws {
        for proxied in [false, true] {
            let fixture = ControlledHTTPFixture(steps: [])
            defer { fixture.invalidate() }
            let service = await fixture.makeOpenAIService(proxied: proxied)
            for id in ["", ".", ".."] {
                do {
                    _ = try await Self.retrieve(service: service, responseID: id)
                    XCTFail("Expected an assertion for invalid response ID")
                } catch AIProxyError.assertion { } catch { XCTFail("Unexpected error: \(error)") }
            }
            XCTAssertTrue(fixture.requests.isEmpty)
        }
    }

    func testAzureIncludesRemainRepeatedAndOrdered() async throws {
        let options: [[OpenAIInclude]?] = [nil, [], [.webSearchCallActionSources], [.webSearchCallActionSources, .fileSearchCallResults], [.fileSearchCallResults, .fileSearchCallResults]]
        for proxied in [false, true] {
            for include in options {
                let fixture = ControlledHTTPFixture(steps: [.http(body: snapshot())])
                defer { fixture.invalidate() }
                let service = await fixture.makeOpenAIService(proxied: proxied, requestFormat: .azureDeployment(apiVersion: "fixture-version"))
                _ = try await Self.retrieve(service: service, include: include)
                let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(fixture.requests.first?.url), resolvingAgainstBaseURL: false))
                let expected = [URLQueryItem(name: "api-version", value: "fixture-version")] + (include ?? []).map { URLQueryItem(name: "include[]", value: $0.rawValue) }
                XCTAssertEqual(components.queryItems, expected)
                XCTAssertEqual(fixture.requests.count, 1)
            }
        }
    }

    func testGETHTTPErrorsPreserveStatusBodyAndHeaders() async throws {
        let failures: [(Int, Data, String, [String: String])] = [
            (300, Data("multiple choices".utf8), "multiple choices", ["X-Request-ID": "req300"]),
            (302, Data("redirect body".utf8), "redirect body", ["Retry-After": "7", "X-Request-ID": "req302"]),
            (400, Data("{\"error\":\"bad request\"}".utf8), "{\"error\":\"bad request\"}", ["X-Request-ID": "req400"]),
            (401, Data("unauthorized".utf8), "unauthorized", ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT", "X-Request-ID": "req401"]),
            (403, Data("forbidden".utf8), "forbidden", ["X-Request-ID": "req403"]),
            (404, Data(), "", ["X-Request-ID": "req404"]),
            (429, Data([0xff, 0xfe]), "", ["Retry-After": "11", "X-Request-ID": "req429"]),
            (500, Data("first line\nsecond line\n".utf8), "first line\nsecond line\n", ["X-Request-ID": "req500"]),
            (503, Data("unavailable".utf8), "unavailable", ["Retry-After": "3", "X-Request-ID": "req503"])
        ]
        for proxied in [false, true] {
            for (status, data, text, headers) in failures {
                let fixture = ControlledHTTPFixture(steps: [.http(statusCode: status, body: data, headers: headers)])
                defer { fixture.invalidate() }
                let service = await fixture.makeOpenAIService(proxied: proxied)
                do {
                    _ = try await Self.retrieve(service: service)
                    XCTFail("Expected HTTP failure")
                } catch let error as AIProxyHTTPError {
                    XCTAssertEqual(error.statusCode, status)
                    XCTAssertEqual(error.responseData, data)
                    XCTAssertEqual(error.responseBody, text)
                    for (name, value) in headers { XCTAssertEqual(header(name, in: error.headers), value) }
                    XCTAssertEqual(header("Retry-After", in: error.headers), headers["Retry-After"])
                } catch { XCTFail("Unexpected error: \(error)") }
                XCTAssertEqual(fixture.requests.count, 1)
            }
            let success = ControlledHTTPFixture(steps: [.http(statusCode: 299, body: snapshot())])
            defer { success.invalidate() }
            let service = await success.makeOpenAIService(proxied: proxied)
            let response = try await Self.retrieve(service: service)
            XCTAssertEqual(response.body.id, "resp_fixture")
            XCTAssertEqual(success.requests.count, 1)
        }
    }

    func testTransportAndDecodeErrorsPropagateWithoutAnotherRequest() async throws {
        for proxied in [false, true] {
            for code in [URLError.timedOut, .networkConnectionLost] {
                let fixture = ControlledHTTPFixture(steps: [.failure(URLError(code))])
                defer { fixture.invalidate() }
                let service = await fixture.makeOpenAIService(proxied: proxied)
                do { _ = try await Self.retrieve(service: service); XCTFail("Expected transport failure") }
                catch let error as URLError { XCTAssertEqual(error.code, code) }
                catch { XCTFail("Unexpected error: \(error)") }
                XCTAssertEqual(fixture.requests.count, 1)
            }
            let fixture = ControlledHTTPFixture(steps: [.http(body: Data("not JSON".utf8))])
            defer { fixture.invalidate() }
            let service = await fixture.makeOpenAIService(proxied: proxied)
            do { _ = try await Self.retrieve(service: service); XCTFail("Expected decoding failure") }
            catch is DecodingError { } catch { XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(fixture.requests.count, 1)
        }
    }

    func testExistingBufferedTransportKeepsLegacyHTTPError() async throws {
        for proxied in [false, true] {
            let body = "rate limit\nfixture detail\n"
            let fixture = ControlledHTTPFixture(steps: [.http(
                statusCode: 429,
                body: Data(body.utf8),
                headers: ["Retry-After": "11", "X-Request-ID": "legacy-fixture"]
            )])
            defer { fixture.invalidate() }
            let session = fixture.makeSession(proxied: proxied)
            let request = URLRequest(url: try XCTUnwrap(URL(string: fixture.baseURL + "/fixture")))
            do {
                _ = try await BackgroundNetworker.makeRequestAndWaitForData(session, request)
                XCTFail("Expected HTTP failure")
            } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
                XCTAssertEqual(statusCode, 429)
                XCTAssertEqual(responseBody, body)
            } catch { XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(fixture.requests.count, 1)
        }
    }

    func testCancellationStopsActiveGETWithoutProviderCancellation() async throws {
        for proxied in [false, true] {
            let fixture = ControlledHTTPFixture(steps: [.blocked])
            defer { fixture.invalidate() }
            let service = await fixture.makeOpenAIService(proxied: proxied)
            let finished = AsyncTestSignal()
            let task = Task {
                defer { finished.fire() }
                return try await Self.retrieve(service: service)
            }
            defer { task.cancel() }
            try await fixture.started.wait()
            task.cancel()
            try await fixture.stopped.wait()
            try await finished.wait()
            do { _ = try await task.value; XCTFail("Expected cancellation") }
            catch is CancellationError { }
            catch let error as URLError { XCTAssertEqual(error.code, .cancelled) }
            catch { XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(fixture.requests.count, 1)
            XCTAssertEqual(fixture.requests.first?.httpMethod, "GET")
            XCTAssertEqual(fixture.requests.first?.url?.path, "/prefix/v1/responses/resp_fixture")
        }
    }
}
#endif
