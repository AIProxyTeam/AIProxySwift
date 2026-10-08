#if DEBUG
import Foundation
@testable import AIProxy

/// Bounded, event-driven synchronization for transport-start and cancellation assertions.
/// The lock protects every state access from synchronous URLProtocol callbacks.
final class AsyncTestSignal: @unchecked Sendable {
    enum DeadlineExceeded: Error { case signal }
    private let lock = NSLock()
    private var fired = false
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    func fire() {
        let pending = lock.withLock {
            fired = true
            let pending = Array(waiters.values)
            waiters.removeAll()
            return pending
        }
        for waiter in pending { waiter.resume() }
    }

    func wait(timeout: TimeInterval = 3) async throws {
        let id = UUID()
        try await withCheckedThrowingContinuation { continuation in
            let completed = lock.withLock {
                if fired { return true }
                waiters[id] = continuation
                return false
            }
            if completed {
                continuation.resume()
            } else {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in
                    let pending = lock.withLock { waiters.removeValue(forKey: id) }
                    pending?.resume(throwing: DeadlineExceeded.signal)
                }
            }
        }
    }
}

/// Each fixture owns a unique host and its scripted responses. No live network is used.
/// All mutable state is lock-protected; callbacks never hold a lock across client calls.
final class ControlledHTTPFixture: @unchecked Sendable {
    enum Step: Sendable {
        case http(statusCode: Int = 200, body: Data, headers: [String: String] = [:], errorAfterBody: URLError? = nil)
        case failure(URLError)
        case stream(body: Data, headers: [String: String] = [:])
        case blocked
    }

    let host = "fixture-\(UUID().uuidString.lowercased()).invalid"
    var baseURL: String { "https://\(host)/prefix" }
    let started = AsyncTestSignal()
    let stopped = AsyncTestSignal()
    let streamReady = AsyncTestSignal()
    private let lock = NSLock()
    private var steps: [Step]
    private var captured: [URLRequest] = []
    private var sessions: [URLSession] = []
    private var activeStream: ControlledHTTPProtocol?

    init(steps: [Step]) {
        self.steps = steps
        ControlledHTTPProtocol.registry.register(self)
    }

    var requests: [URLRequest] { lock.withLock { captured } }

    fileprivate func start(_ request: URLRequest) -> Step {
        let step = lock.withLock {
            captured.append(request)
            return steps.isEmpty ? .failure(URLError(.unsupportedURL)) : steps.removeFirst()
        }
        started.fire()
        return step
    }

    fileprivate func registerStream(_ stream: ControlledHTTPProtocol) {
        lock.withLock { activeStream = stream }
    }

    /// Release a stream only after the test observed an emitted event or streamReady.
    func finishStream(error: URLError? = nil) {
        let stream = lock.withLock {
            let stream = activeStream
            activeStream = nil
            return stream
        }
        stream?.finishStream(error: error)
    }

    func invalidate() {
        let active = lock.withLock { sessions }
        for session in active { session.invalidateAndCancel() }
        ControlledHTTPProtocol.registry.remove(host: host)
    }

    func makeSession(proxied: Bool) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ControlledHTTPProtocol.self]
        let delegate: any URLSessionDelegate = proxied ? AIProxyCertificatePinningDelegate() : DirectURLSessionDataDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        lock.withLock { sessions.append(session) }
        return session
    }

    @AIProxyActor func makeOpenAIService(
        proxied: Bool,
        requestFormat: OpenAIRequestFormat = .standard,
        deviceCheckTokenProvider: @escaping @AIProxyActor @Sendable (String?) async -> String? = { _ in "fixture-device-token" }
    ) -> OpenAIService {
        let builder: any AIProxyRequestBuilder
        if proxied {
            builder = AIProxyProxiedRequestBuilder(
                partialKey: "fixture-partial-key",
                serviceURL: baseURL,
                clientID: "fixture-client-id",
                deviceCheckTokenProvider: deviceCheckTokenProvider
            )
        } else {
            builder = AIProxyDirectRequestBuilder(
                baseURL: baseURL,
                unprotectedAuthHeader: (key: "Authorization", value: "Bearer fixture-api-key")
            )
        }
        return OpenAIService(
            requestFormat: requestFormat,
            requestBuilder: builder,
            serviceNetworker: ControlledSessionNetworker(urlSession: makeSession(proxied: proxied))
        )
    }
}

@AIProxyActor struct ControlledSessionNetworker: ServiceMixin {
    let urlSession: URLSession
}

private final class ControlledFixtureRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var fixtures: [String: ControlledHTTPFixture] = [:]
    func register(_ fixture: ControlledHTTPFixture) { lock.withLock { fixtures[fixture.host] = fixture } }
    func remove(host: String) { _ = lock.withLock { fixtures.removeValue(forKey: host) } }
    func fixture(host: String?) -> ControlledHTTPFixture? { lock.withLock { host.flatMap { fixtures[$0] } } }
}

private final class ControlledHTTPProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ControlledFixtureRegistry()

    override class func canInit(with request: URLRequest) -> Bool { registry.fixture(host: request.url?.host) != nil }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let fixture = Self.registry.fixture(host: request.url?.host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch fixture.start(request) {
        case .http(let statusCode, let body, let headers, let errorAfterBody):
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
            // Delivering a 302 response directly intentionally disables redirect following.
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !body.isEmpty { client?.urlProtocol(self, didLoad: body) }
            if let errorAfterBody {
                client?.urlProtocol(self, didFailWithError: errorAfterBody)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .stream(let body, let headers):
            fixture.registerStream(self)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !body.isEmpty { client?.urlProtocol(self, didLoad: body) }
            fixture.streamReady.fire()
        case .blocked:
            break
        }
    }

    func finishStream(error: URLError?) {
        if let error { client?.urlProtocol(self, didFailWithError: error) }
        else { client?.urlProtocolDidFinishLoading(self) }
    }

    override func stopLoading() {
        Self.registry.fixture(host: request.url?.host)?.stopped.fire()
    }
}
#endif
