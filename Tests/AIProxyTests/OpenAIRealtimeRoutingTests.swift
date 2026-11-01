import Foundation
import Testing
@testable import AIProxy

@AIProxyActor
@Suite(.serialized)
struct OpenAIRealtimeRoutingTests {
    @Test
    func directRealtimeRequestRetainsSecureRouteAndAuthorization() async throws {
        let builder = AIProxyDirectRequestBuilder(
            baseURL: "https://api.openai.com",
            unprotectedAuthHeader: ("Authorization", "Bearer fixture-key")
        )
        let request = try await builder.plainGET(
            path: "/v1/realtime?model=fixture-model",
            secondsToWait: 60,
            additionalHeaders: [:]
        )
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/realtime?model=fixture-model")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 60)
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-key")
    }

    @Test
    func directAndProxiedNetworkersRetainTheirConfiguredDelegates() {
        let direct = DirectServiceNetworker().urlSession
        let proxied = ProxiedServiceNetworker().urlSession
        #expect(direct === AIProxyUtils.directURLSession)
        #expect(direct.delegate is DirectURLSessionDataDelegate)
        #expect(proxied === AIProxyURLSession.urlSession)
        #expect(proxied.delegate === AIProxyURLSession.delegate)
        #expect(proxied.delegate is AIProxyCertificatePinningDelegate)
        #expect(direct !== proxied)
    }

    @Test(arguments: ["direct", "proxy"])
    func factoryUsesSelectedRequestAndURLSessionWithoutReplacingHeaders(_ route: String) async throws {
        // These requests test the service/factory boundary. The real proxy builder
        // requires DeviceCheck and is separately preserved by source comparison.
        let server = try RealtimeLoopbackServer()
        defer { server.stop() }
        var components = try #require(URLComponents(url: try await server.listening.value(), resolvingAgainstBaseURL: false))
        components.path = "/\(route)/v1/realtime"
        components.queryItems = [.init(name: "model", value: "fixture-model")]
        var request = URLRequest(url: try #require(components.url))
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("fixture-key", forHTTPHeaderField: route == "direct" ? "Authorization" : "X-AIProxy-Partial-Key")
        request.setValue("fixture-client", forHTTPHeaderField: "X-Fixture-Client")
        let builder = RealtimeCapturingRequestBuilder(request: request)
        let selectedSession = URLSession(configuration: .ephemeral)
        defer { selectedSession.invalidateAndCancel() }
        let networker = RealtimeSelectedNetworker(selectedSession: selectedSession)
        let service = OpenAIService(
            requestFormat: .standard,
            requestBuilder: builder,
            serviceNetworker: networker
        )
        let originalLogLevel = AIProxyLogLevel.callerDesiredLogLevel
        defer { AIProxyLogLevel.callerDesiredLogLevel = originalLogLevel }
        let session = try await service.realtimeSession(model: "fixture-model", configuration: .init(), logLevel: .warning)
        defer { session.disconnect() }
        #expect(builder.calls.count == 1)
        #expect(builder.calls.first?.path == "/v1/realtime?model=fixture-model")
        #expect(builder.calls.first?.secondsToWait == 60)
        #expect(builder.calls.first?.additionalHeaders == [:])
        #expect(builder.calls.first?.baseURLOverride == nil)
        try await server.upgraded.value()
        let tasks = RealtimeTestSignal<[URLSessionTask]>()
        selectedSession.getAllTasks { tasks.succeed($0) }
        let selectedTasks = try await tasks.value()
        #expect(networker.selectionCount == 1)
        #expect(selectedTasks.count == 1)
        #expect(selectedTasks.first is URLSessionWebSocketTask)
        let constructed = try #require(selectedTasks.first?.originalRequest)
        #expect(constructed.url == request.url)
        #expect(constructed.httpMethod == request.httpMethod)
        #expect(constructed.timeoutInterval == request.timeoutInterval)
        #expect(constructed.httpBody == request.httpBody)
        // Foundation adds its required WebSocket handshake headers. Every supplied
        // routing/authentication header must still retain its exact original value.
        for (name, value) in request.allHTTPHeaderFields ?? [:] {
            #expect(constructed.value(forHTTPHeaderField: name) == value)
        }
    }
}

@AIProxyActor
private final class RealtimeCapturingRequestBuilder: AIProxyRequestBuilder {
    struct Call {
        let path: String
        let secondsToWait: UInt
        let additionalHeaders: [String: String]
        let baseURLOverride: String?
    }
    let request: URLRequest
    private(set) var calls: [Call] = []

    init(request: URLRequest) { self.request = request }

    func plainGET(path: String, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest {
        calls.append(.init(path: path, secondsToWait: secondsToWait, additionalHeaders: additionalHeaders, baseURLOverride: baseURLOverride))
        return request
    }

    func jsonPOST(path: String, body: Encodable, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest {
        throw RealtimeTestFailure.invalidHandshake
    }
    func multipartPOST(path: String, body: MultipartFormEncodable, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest {
        throw RealtimeTestFailure.invalidHandshake
    }
    func plainDELETE(path: String, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest {
        throw RealtimeTestFailure.invalidHandshake
    }
}

@AIProxyActor
private final class RealtimeSelectedNetworker: ServiceMixin {
    let selectedSession: URLSession
    private(set) var selectionCount = 0

    init(selectedSession: URLSession) { self.selectedSession = selectedSession }

    var urlSession: URLSession {
        selectionCount += 1
        return selectedSession
    }
}
