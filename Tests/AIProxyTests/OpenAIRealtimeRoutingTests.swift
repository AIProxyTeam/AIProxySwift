import Foundation
import Network
import Testing
@testable import AIProxy

@AIProxyActor
@Suite(.serialized)
struct OpenAIRealtimeRoutingTests {
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

    @Test(arguments: ["http", "ws"], ["127.0.0.1", "[::1]"])
    func directFactoryForwardsAuthorizationToCustomEndpoint(_ scheme: String, _ host: String) async throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: host == "[::1]" ? "::1" : "127.0.0.1", port: .any)
        let server = try RealtimeLoopbackServer(parameters: parameters)
        defer { server.stop() }
        let port = try #require(try await server.listening.value().port)
        let service = AIProxy.openAIDirectService(unprotectedAPIKey: "fixture", baseURL: "\(scheme)://\(host):\(port)/custom")
        let session = try await start(service)
        defer { session.disconnect() }
        let request = try await server.requestReceived.value()
        #expect(request.hasPrefix("GET /custom/v1/realtime?model=fixture HTTP/1.1\r\n"))
        #expect(headerValues("Host", in: request) == ["\(host):\(port)"])
        #expect(headerValues("Authorization", in: request) == ["Bearer fixture"])
        _ = try await server.firstClientText.value()
    }

    @Test
    func factoryPreservesOneMiBIncomingMessageLimit() async throws {
        let peer = try RealtimeLoopbackServer()
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        let service = AIProxy.openAIDirectService(unprotectedAPIKey: "fixture", baseURL: "ws://127.0.0.1:\(port)")
        let session = try await start(service)
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 1)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        _ = try await peer.firstClientText.value()
        let event = RealtimeTestFixtures.text
        let limit = 1 << 20
        let atLimit = event + String(repeating: " ", count: limit - event.utf8.count)
        try await peer.sendText([atLimit])
        let delivered = try await recorder.delivered.value()
        #expect(delivered.map(RealtimeMessageRecorder.label) == ["text:Ready"])
        try await peer.sendText([atLimit + " "])
        do {
            try await recorder.finished.value()
            Issue.record("An oversized WebSocket message must fail the receiver")
        } catch NWError.posix(let code) {
            #expect(code == .EMSGSIZE)
            #expect(recorder.messages.count == 1)
        }
    }

    @Test(arguments: ["https", "wss"], [tls_protocol_version_t.TLSv12, .TLSv13])
    func matchingProxyPinAllowsSecureUpgradeAndForwardsRoutingHeaders(
        _ scheme: String, _ version: tls_protocol_version_t
    ) async throws {
        let (peer, key) = try RealtimeTLSFixture.server(onlyTLSVersion: version)
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        let builder = RoutingRequestBuilder(url: URL(string: "\(scheme)://127.0.0.1:\(port)/tenant%2Fone/v1/realtime?model=fixture")!)
        let networker = FixtureProxiedNetworker(keys: [key], trustFixture: true)
        defer { networker.urlSession.invalidateAndCancel() }
        let service = OpenAIService(requestFormat: .standard, requestBuilder: builder, serviceNetworker: networker)
        let session = try await start(service)
        defer { session.disconnect() }
        #expect(builder.path == "/v1/realtime?model=fixture")
        #expect(builder.timeout == 60)
        let request = try await peer.requestReceived.value()
        #expect(request.hasPrefix("GET /tenant%2Fone/v1/realtime?model=fixture HTTP/1.1\r\n"))
        #expect(headerValues("Host", in: request) == ["127.0.0.1:\(port)"])
        for (name, value) in RoutingRequestBuilder.proxyHeaders {
            #expect(headerValues(name, in: request) == [value])
        }
        _ = try await peer.firstClientText.value()
    }

    @Test
    func matchingProxyPinStillRequiresModernTLS() async throws {
        // Offer only the TLS 1.1 wire version (RFC 4346). The key matches the configured pin.
        let tls11 = try #require(tls_protocol_version_t(rawValue: 0x0302))
        let (peer, key) = try RealtimeTLSFixture.server(onlyTLSVersion: tls11)
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        let networker = FixtureProxiedNetworker(keys: [key], trustFixture: true)
        defer { networker.urlSession.invalidateAndCancel() }
        let service = OpenAIService(
            requestFormat: .standard,
            requestBuilder: RoutingRequestBuilder(url: URL(string: "https://127.0.0.1:\(port)")!),
            serviceNetworker: networker
        )
        let session = try await start(service)
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("A matching key must still require TLS 1.2 or later")
        } catch NWError.tls {}
    }

    #if DEBUG && !targetEnvironment(simulator)
    @Test
    func realProxyRequestBuilderForwardsItsAuthenticationToThePeer() async throws {
        let (peer, key) = try RealtimeTLSFixture.server()
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        let builder = AIProxyProxiedRequestBuilder(
            partialKey: "fixture",
            serviceURL: "https://127.0.0.1:\(port)/tenant%2Fone",
            clientID: "fixture-client",
            deviceCheckTokenProvider: { _ in "fixture-token" }
        )
        let networker = FixtureProxiedNetworker(keys: [key], trustFixture: true)
        defer { networker.urlSession.invalidateAndCancel() }
        let service = OpenAIService(requestFormat: .standard, requestBuilder: builder, serviceNetworker: networker)
        let session = try await start(service)
        defer { session.disconnect() }
        let request = try await peer.requestReceived.value()
        #expect(request.hasPrefix("GET /tenant%2Fone/v1/realtime?model=fixture HTTP/1.1\r\n"))
        #expect(headerValues("aiproxy-partial-key", in: request) == ["fixture"])
        #expect(headerValues("aiproxy-client-id", in: request) == ["fixture-client"])
        #expect(headerValues("aiproxy-devicecheck", in: request) == ["fixture-token"])
        #expect(headerValues("aiproxy-metadata", in: request).first?.isEmpty == false)
        _ = try await peer.firstClientText.value()
    }
    #endif

    @Test(arguments: ["http://example.invalid", "ws://example.invalid", "ftp://127.0.0.1"])
    func directRejectsRemoteCleartextAndUnsupportedSchemes(_ baseURL: String) async throws {
        let service = AIProxy.openAIDirectService(unprotectedAPIKey: "fixture", baseURL: baseURL)
        await #expect(throws: URLError(.unsupportedURL)) { _ = try await start(service) }
    }

    @Test(arguments: [true, false])
    func publicTrustPoliciesRejectUntrustedPeer(_ direct: Bool) async throws {
        let (peer, _) = try RealtimeTLSFixture.server()
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        let url = URL(string: "https://127.0.0.1:\(port)")!
        let service: OpenAIService
        if direct {
            service = AIProxy.openAIDirectService(unprotectedAPIKey: "fixture", baseURL: url.absoluteString)
        } else {
            service = OpenAIService(
                requestFormat: .standard,
                requestBuilder: RoutingRequestBuilder(url: url),
                serviceNetworker: ProxiedServiceNetworker()
            )
        }
        try await expectTLSFailure(service, peer: peer)
    }

    @Test(arguments: [
        ("127.0.0.1", false, true),          // Untrusted issuer, matching pin
        ("127.0.0.1", true, false),          // Trusted certificate, wrong pin
        ("unlisted.localhost", true, true),  // Trusted certificate and pin, wrong hostname
    ])
    func proxyRequiresTrustedHostnameAndPinnedKey(host: String, trusted: Bool, pinMatches: Bool) async throws {
        let (peer, key) = try RealtimeTLSFixture.server()
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        var configuredPin = key
        if !pinMatches {
            configuredPin[configuredPin.startIndex] ^= 1
        }
        let networker = FixtureProxiedNetworker(keys: [configuredPin], trustFixture: trusted)
        defer { networker.urlSession.invalidateAndCancel() }
        let service = OpenAIService(
            requestFormat: .standard,
            requestBuilder: RoutingRequestBuilder(url: URL(string: "https://\(host):\(port)")!),
            serviceNetworker: networker
        )
        try await expectTLSFailure(service, peer: peer)
    }

    private func expectTLSFailure(_ service: OpenAIService, peer: RealtimeLoopbackServer) async throws {
        let session = try await start(service)
        defer { session.disconnect() }
        let recorder = RealtimeMessageRecorder(expectedCount: 0)
        let reader = recorder.consume(session.receiver)
        defer { reader.cancel() }
        do {
            try await recorder.finished.value()
            Issue.record("The TLS handshake accepted an untrusted peer")
        } catch NWError.tls {
            #expect(!peer.requestReceived.hasSucceeded)
        }
    }

    @Test(arguments: ["http", "ws", "ftp"])
    func proxyRejectsSchemesWithoutTLS(_ scheme: String) async throws {
        let builder = RoutingRequestBuilder(url: URL(string: "\(scheme)://127.0.0.1")!)
        let service = OpenAIService(requestFormat: .standard, requestBuilder: builder, serviceNetworker: ProxiedServiceNetworker())
        await #expect(throws: URLError(.unsupportedURL)) { _ = try await start(service) }
    }

    @Test(arguments: [true, false])
    func urlSessionDelegateMakesTheSamePinDecision(_ match: Bool) async throws {
        let (peer, key) = try RealtimeTLSFixture.server(upgrade: .httpOK)
        defer { peer.stop() }
        let port = try #require(try await peer.listening.value().port)
        let url = try #require(URL(string: "https://127.0.0.1:\(port)/pin-check"))
        let request = URLRequest(url: url, timeoutInterval: 5)
        let urlSession = FixtureProxiedNetworker(keys: match ? [key] : []).urlSession
        defer { urlSession.invalidateAndCancel() }

        do {
            let (body, response) = try await urlSession.data(for: request)
            #expect(match)
            #expect((response as? HTTPURLResponse)?.statusCode == 200)
            #expect(body == Data("ok".utf8))
            #expect(try await peer.requestReceived.value().hasPrefix("GET /pin-check HTTP/1.1\r\n"))
        } catch let error as URLError {
            #expect(!match)
            #expect([URLError.Code.cancelled, .secureConnectionFailed, .serverCertificateUntrusted].contains(error.code))
            #expect(!peer.requestReceived.hasSucceeded)
        }
    }

    @Test
    func rejectsRequestWithoutAHost() async throws {
        let builder = RoutingRequestBuilder(url: URL(fileURLWithPath: "/fixture"))
        let service = OpenAIService(requestFormat: .standard, requestBuilder: builder, serviceNetworker: DirectServiceNetworker())
        await #expect(throws: URLError(.badURL)) { _ = try await start(service) }
    }

    private func start(_ service: OpenAIService) async throws -> OpenAIRealtimeSession {
        let originalLogLevel = AIProxyLogLevel.callerDesiredLogLevel
        defer { AIProxyLogLevel.callerDesiredLogLevel = originalLogLevel }
        return try await service.realtimeSession(model: "fixture", configuration: .init(), logLevel: .warning)
    }

    private func headerValues(_ name: String, in request: String) -> [String] {
        request.components(separatedBy: "\r\n").compactMap { line in
            let pair = line.split(separator: ":", maxSplits: 1)
            guard pair.count == 2, pair[0].caseInsensitiveCompare(name) == .orderedSame else { return nil }
            return pair[1].trimmingCharacters(in: .whitespaces)
        }
    }
}

@AIProxyActor
private final class FixtureProxiedNetworker: ProxiedService {
    let urlSession: URLSession

    init(keys: [Data], trustFixture: Bool = false) {
        let delegate = AIProxyCertificatePinningDelegate(
            pinnedPublicKeys: keys,
            configureRealtimeTrust: { RealtimeTLSFixture.configureTrust($0, trustFixture: trustFixture) }
        )
        urlSession = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }
}

/// Supplies deterministic proxy headers at the same request-builder boundary used by DeviceCheck.
@AIProxyActor
final class RoutingRequestBuilder: AIProxyRequestBuilder {
    static let proxyHeaders = ["aiproxy-partial-key": "fixture", "aiproxy-client-id": "fixture-client", "aiproxy-devicecheck": "fixture-token", "aiproxy-metadata": "fixture-metadata"]

    let url: URL
    let requestTimeout: TimeInterval?
    private(set) var path: String?
    private(set) var timeout: UInt?

    init(url: URL, requestTimeout: TimeInterval? = nil) {
        self.url = url
        self.requestTimeout = requestTimeout
    }

    func plainGET(path: String, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest {
        self.path = path
        timeout = secondsToWait
        var request = URLRequest(url: url, timeoutInterval: requestTimeout ?? TimeInterval(secondsToWait))
        request.allHTTPHeaderFields = Self.proxyHeaders
        return request
    }

    func jsonPOST(path: String, body: Encodable, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest { throw RealtimeTestFailure.invalidHandshake }
    func multipartPOST(path: String, body: MultipartFormEncodable, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest { throw RealtimeTestFailure.invalidHandshake }
    func plainDELETE(path: String, secondsToWait: UInt, additionalHeaders: [String: String], baseURLOverride: String?) async throws -> URLRequest { throw RealtimeTestFailure.invalidHandshake }
}
