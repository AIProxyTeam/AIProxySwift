import CryptoKit
import Foundation
import Testing
@testable import AIProxy

// MARK: - Fakes

/// Stands in for DCAppAttestService. Records every call and hands out scripted key IDs.
final class FakeAttestationService: AIProxyAttestationService, @unchecked Sendable {
    private let lock = NSLock()
    private var _supported = true
    private var _keyIDs: [String]
    private var _attestCalls: [(keyID: String, clientDataHash: Data)] = []
    private var _assertionCalls: [(keyID: String, clientDataHash: Data)] = []
    private var _invalidKeys: Set<String> = []

    init(keyIDs: [String] = ["key-1", "key-2"]) {
        self._keyIDs = keyIDs
    }

    var isSupported: Bool {
        lock.lock(); defer { lock.unlock() }
        return _supported
    }

    func setSupported(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        _supported = value
    }

    var attestCalls: [(keyID: String, clientDataHash: Data)] {
        lock.lock(); defer { lock.unlock() }
        return _attestCalls
    }

    var assertionCalls: [(keyID: String, clientDataHash: Data)] {
        lock.lock(); defer { lock.unlock() }
        return _assertionCalls
    }

    /// The next assertion with this key fails as Apple would for a revoked key.
    func invalidate(_ keyID: String) {
        lock.lock(); defer { lock.unlock() }
        _invalidKeys.insert(keyID)
    }

    func generateKey() async throws -> String {
        lock.withLock { _keyIDs.removeFirst() }
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        lock.withLock { _attestCalls.append((keyID, clientDataHash)) }
        return Data("attestation-for-\(keyID)".utf8)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        let invalid = lock.withLock {
            _assertionCalls.append((keyID, clientDataHash))
            return _invalidKeys.remove(keyID) != nil
        }
        if invalid {
            throw AIProxyAttestationKeyInvalid()
        }
        return Data("assertion-\(keyID)".utf8) + clientDataHash.prefix(4)
    }
}

final class InMemoryKeyStore: AIProxyAppAttestKeyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    func keyID(for scope: String) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[scope]
    }

    func setKeyID(_ keyID: String, for scope: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[scope] = keyID
    }

    func deleteKeyID(for scope: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: scope)
    }
}

/// Answers the challenge and register routes with scripted responses and records what it received.
final class ScriptedTransport: AIProxyAppAttestHTTPTransport, @unchecked Sendable {
    struct Response {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]
    }

    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    var challengeResponse: Response
    var registerResponse: Response

    init(challenge: Data = Data(repeating: 7, count: 32)) {
        let challengeBody = try! JSONEncoder().encode(["challenge": challenge.base64EncodedString(), "expires_in": "300"])
        self.challengeResponse = Response(status: 200, body: challengeBody)
        self.registerResponse = Response(status: 204, body: Data())
    }

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let scripted = lock.withLock {
            _requests.append(request)
            let path = request.url?.path ?? ""
            return path.hasSuffix("/challenge") ? challengeResponse : registerResponse
        }
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: scripted.status,
            httpVersion: "HTTP/1.1",
            headerFields: scripted.headers
        )!
        return (scripted.body, http)
    }
}

// MARK: - Helpers

private let serviceURL = "https://api.aiproxy.com/dd6bcfd0/c27411bd"
private let scope = "https://api.aiproxy.com#dd6bcfd0"

private func makeClient(
    attestation: FakeAttestationService = FakeAttestationService(),
    store: InMemoryKeyStore = InMemoryKeyStore(),
    transport: ScriptedTransport = ScriptedTransport(),
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_700_000_000) }
) -> AIProxyAppAttestClient {
    AIProxyAppAttestClient(
        host: URL(string: "https://api.aiproxy.com")!,
        projectID: "dd6bcfd0",
        scope: scope,
        attestation: attestation,
        store: store,
        transport: transport,
        now: now,
        makeNonce: { "AAAAAAAAAAAAAAAAAAAAAA==" },
        clientID: { "client-1" }
    )
}

// MARK: - Tests

@Suite("App Attest signing", .serialized)
struct AIProxyAppAttestSigningTests {

    @Test("Client data hash matches the vector pinned by eproxy and the other AIProxy packages")
    func pinnedHashVector() {
        let hash = AIProxyAppAttestSigning.clientDataHash(
            method: "POST",
            path: "/p/s/v1/generate",
            body: Data("{}".utf8),
            nonce: "AAAAAAAAAAAAAAAAAAAAAA==",
            timestamp: 1_700_000_000,
            keyID: "a2V5"
        )
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        #expect(hex == "fc495a464c7e58931e1a74595b62bc1d002d8ff2856706f6dc01f373f9e25d09")
    }

    @Test("The signed path is percent-encoded and excludes the query string")
    func signedPath() {
        let url = URL(string: "https://api.aiproxy.com/p/s/v1/realtime?model=gpt-4o%20mini&x=1#frag")!
        #expect(AIProxyAppAttestSigning.signedPath(of: url) == "/p/s/v1/realtime")

        let encoded = URL(string: "https://api.aiproxy.com/p/s/v1beta/models/gemini:streamGenerateContent?alt=sse")!
        #expect(AIProxyAppAttestSigning.signedPath(of: encoded) == "/p/s/v1beta/models/gemini:streamGenerateContent")

        #expect(AIProxyAppAttestSigning.signedPath(of: URL(string: "https://api.aiproxy.com")!) == "/")
    }

    @Test("Nonces are 16 random bytes, base64 encoded, and unique")
    func nonce() {
        let a = AIProxyAppAttestSigning.randomNonce()
        let b = AIProxyAppAttestSigning.randomNonce()
        #expect(Data(base64Encoded: a)?.count == 16)
        #expect(a != b)
    }

    @Test("App URLs and service URLs both yield the host and the app; anything else is rejected")
    func appURLParsing() throws {
        let app = try AIProxyAppAttestClient.parseAppURL("https://api.aiproxy.com/dd6bcfd0")
        #expect(app.host.absoluteString == "https://api.aiproxy.com")
        #expect(app.projectID == "dd6bcfd0")

        let service = try AIProxyAppAttestClient.parseAppURL("https://api.aiproxy.com/dd6bcfd0/c27411bd")
        #expect(service.projectID == "dd6bcfd0")

        let local = try AIProxyAppAttestClient.parseAppURL("http://lou.local:4000/p/s")
        #expect(local.host.absoluteString == "http://lou.local:4000")

        #expect(throws: AIProxyError.appAttestRequiresServiceURL) {
            _ = try AIProxyAppAttestClient.parseAppURL("https://api.aiproxy.pro")
        }
        #expect(throws: AIProxyError.appAttestRequiresServiceURL) {
            _ = try AIProxyAppAttestClient.parseAppURL("https://api.aiproxy.com/a/b/c")
        }
    }
}

@Suite("App Attest client", .serialized)
struct AIProxyAppAttestClientTests {

    @Test("First use registers the key at the app's route: challenge, attest over SHA256(challenge), register, persist")
    func registration() async throws {
        let attestation = FakeAttestationService()
        let store = InMemoryKeyStore()
        let challenge = Data(repeating: 7, count: 32)
        let transport = ScriptedTransport(challenge: challenge)
        let client = makeClient(attestation: attestation, store: store, transport: transport)

        try await client.attestIfNeeded()

        let requests = transport.requests
        #expect(requests.count == 2)
        // Attestation is per app: no service segment in the route.
        #expect(requests[0].url?.absoluteString == "https://api.aiproxy.com/dd6bcfd0/aiproxy/v1/attest/challenge")
        #expect(requests[1].url?.absoluteString == "https://api.aiproxy.com/dd6bcfd0/aiproxy/v1/attest/register")
        for request in requests {
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "aiproxy-client-id") == "client-1")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "aiproxy-metadata") != nil)
        }

        let challengeBody = try JSONDecoder().decode([String: String].self, from: requests[0].httpBody!)
        #expect(challengeBody == ["key_id": "key-1"])

        let registerBody = try JSONDecoder().decode([String: String].self, from: requests[1].httpBody!)
        #expect(registerBody["key_id"] == "key-1")
        #expect(registerBody["attestation_object"] == Data("attestation-for-key-1".utf8).base64EncodedString())

        #expect(attestation.attestCalls.count == 1)
        #expect(attestation.attestCalls[0].clientDataHash == Data(SHA256.hash(data: challenge)))
        #expect(try store.keyID(for: scope) == "key-1")

        // Second call is a no-op.
        try await client.attestIfNeeded()
        #expect(transport.requests.count == 2)
    }

    @Test("A stored key skips registration entirely")
    func storedKeyIsReused() async throws {
        let store = InMemoryKeyStore()
        try store.setKeyID("stored-key", for: scope)
        let transport = ScriptedTransport()
        let client = makeClient(store: store, transport: transport)

        let headers = try await client.signatureHeaders(method: "POST", url: URL(string: serviceURL + "/v1/messages")!, body: nil)

        #expect(headers[AIProxyAppAttestHeaders.keyID] == "stored-key")
        #expect(transport.requests.isEmpty)
    }

    @Test("Signing adds the four headers and the assertion covers method, full path, body, nonce, timestamp, and key ID")
    func signatureHeaders() async throws {
        let attestation = FakeAttestationService()
        let client = makeClient(attestation: attestation)
        let body = Data(#"{"model":"claude-sonnet-5"}"#.utf8)
        let url = URL(string: serviceURL + "/v1/messages?beta=true")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        try await client.sign(&request)

        #expect(request.value(forHTTPHeaderField: AIProxyAppAttestHeaders.keyID) == "key-1")
        #expect(request.value(forHTTPHeaderField: AIProxyAppAttestHeaders.nonce) == "AAAAAAAAAAAAAAAAAAAAAA==")
        #expect(request.value(forHTTPHeaderField: AIProxyAppAttestHeaders.timestamp) == "1700000000")

        let expectedHash = AIProxyAppAttestSigning.clientDataHash(
            method: "POST",
            path: "/dd6bcfd0/c27411bd/v1/messages",
            body: body,
            nonce: "AAAAAAAAAAAAAAAAAAAAAA==",
            timestamp: 1_700_000_000,
            keyID: "key-1"
        )
        #expect(attestation.assertionCalls.count == 1)
        #expect(attestation.assertionCalls[0].clientDataHash == expectedHash)

        let expectedAssertion = (Data("assertion-key-1".utf8) + expectedHash.prefix(4)).base64EncodedString()
        #expect(request.value(forHTTPHeaderField: AIProxyAppAttestHeaders.assertion) == expectedAssertion)
    }

    @Test("A GET with no body signs the empty body, as the WebSocket upgrade does")
    func emptyBody() async throws {
        let attestation = FakeAttestationService()
        let client = makeClient(attestation: attestation)

        _ = try await client.signatureHeaders(method: "GET", url: URL(string: serviceURL + "/v1/realtime?model=x")!, body: nil)

        let expected = AIProxyAppAttestSigning.clientDataHash(
            method: "GET",
            path: "/dd6bcfd0/c27411bd/v1/realtime",
            body: Data(),
            nonce: "AAAAAAAAAAAAAAAAAAAAAA==",
            timestamp: 1_700_000_000,
            keyID: "key-1"
        )
        #expect(attestation.assertionCalls[0].clientDataHash == expected)
    }

    @Test("A key Apple reports as invalid is forgotten and re-attested once")
    func invalidKeyIsReplaced() async throws {
        let attestation = FakeAttestationService(keyIDs: ["key-1", "key-2"])
        let store = InMemoryKeyStore()
        let transport = ScriptedTransport()
        let client = makeClient(attestation: attestation, store: store, transport: transport)

        try await client.attestIfNeeded()
        attestation.invalidate("key-1")

        let headers = try await client.signatureHeaders(method: "POST", url: URL(string: serviceURL + "/v1/messages")!, body: nil)

        #expect(headers[AIProxyAppAttestHeaders.keyID] == "key-2")
        #expect(try store.keyID(for: scope) == "key-2")
        #expect(transport.requests.count == 4)
        #expect(attestation.assertionCalls.map(\.keyID) == ["key-1", "key-2"])
    }

    @Test("A failed registration surfaces the server's status and body, then backs off")
    func registrationFailureBacksOff() async throws {
        let transport = ScriptedTransport()
        transport.registerResponse = .init(status: 403, body: Data(#"{"error":{"type":"app_attest_registration_failed","message":"wrong bundle"}}"#.utf8))
        let client = makeClient(transport: transport)

        await #expect(throws: AIProxyError.appAttestRegistrationFailed(
            statusCode: 403,
            responseBody: #"{"error":{"type":"app_attest_registration_failed","message":"wrong bundle"}}"#,
            retryAfter: nil
        )) {
            try await client.attestIfNeeded()
        }

        // The next attempt does not touch the network while backing off.
        do {
            try await client.attestIfNeeded()
            Issue.record("expected a backoff error")
        } catch AIProxyError.appAttestRegistrationBackingOff(let until, _) {
            #expect(until == Date(timeIntervalSince1970: 1_700_000_060))
        }
        #expect(transport.requests.count == 2)
    }

    @Test("A 429 honors Retry-After for the backoff")
    func quotaBackoff() async throws {
        let transport = ScriptedTransport()
        transport.challengeResponse = .init(status: 429, body: Data(), headers: ["Retry-After": "120"])
        let client = makeClient(transport: transport)

        await #expect(throws: AIProxyError.self) {
            try await client.attestIfNeeded()
        }

        do {
            try await client.attestIfNeeded()
            Issue.record("expected a backoff error")
        } catch AIProxyError.appAttestRegistrationBackingOff(let until, _) {
            #expect(until == Date(timeIntervalSince1970: 1_700_000_120))
        }
    }

    @Test("Unsupported hardware throws appAttestIsUnavailable instead of contacting the server")
    func unsupported() async throws {
        let attestation = FakeAttestationService()
        attestation.setSupported(false)
        let transport = ScriptedTransport()
        let client = makeClient(attestation: attestation, transport: transport)

        #expect(client.isSupported == false)
        await #expect(throws: AIProxyError.appAttestIsUnavailable) {
            try await client.attestIfNeeded()
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("Concurrent first requests register once")
    func concurrentRegistration() async throws {
        let transport = ScriptedTransport()
        let client = makeClient(transport: transport)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { try await client.attestIfNeeded() }
            }
            try await group.waitForAll()
        }

        #expect(transport.requests.count == 2)
    }

    @Test("An app_attest_unknown_key rejection resets the shared client for that app")
    func unknownKeyResetsSharedClient() async throws {
        AIProxyAppAttestClient.resetSharedClients()
        defer { AIProxyAppAttestClient.resetSharedClients() }

        let store = InMemoryKeyStore()
        try store.setKeyID("stale-key", for: scope)
        let transport = ScriptedTransport()
        let client = AIProxyAppAttestClient.sharedClient(scope: scope) {
            makeClient(store: store, transport: transport)
        }

        // Warm the cache so the reset has something to forget.
        _ = try await client.signatureHeaders(method: "POST", url: URL(string: serviceURL + "/v1/messages")!, body: nil)
        #expect(try store.keyID(for: scope) == "stale-key")

        AIProxyAppAttestClient.noteRejection(
            responseBody: #"{"error":{"type":"app_attest_unknown_key","message":"attest again"}}"#,
            requestURL: URL(string: serviceURL + "/v1/messages?stream=true")
        )

        // The reset is dispatched to the actor; give it a moment.
        for _ in 0..<50 where try store.keyID(for: scope) != nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(try store.keyID(for: scope) == nil)

        // The next request attests again with a fresh key.
        let headers = try await client.signatureHeaders(method: "POST", url: URL(string: serviceURL + "/v1/messages")!, body: nil)
        #expect(headers[AIProxyAppAttestHeaders.keyID] == "key-1")
        #expect(transport.requests.count == 2)
    }

    @Test("Other rejections leave the shared client alone")
    func otherRejectionsAreIgnored() async throws {
        AIProxyAppAttestClient.resetSharedClients()
        defer { AIProxyAppAttestClient.resetSharedClients() }

        let store = InMemoryKeyStore()
        try store.setKeyID("good-key", for: scope)
        _ = AIProxyAppAttestClient.sharedClient(scope: scope) { makeClient(store: store) }

        AIProxyAppAttestClient.noteRejection(
            responseBody: #"{"error":{"type":"rate_limited","message":"app_attest_unknown_key is mentioned but not the type"}}"#,
            requestURL: URL(string: serviceURL + "/v1/messages")
        )
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(try store.keyID(for: scope) == "good-key")
    }

    @Test("The app URL and its service URLs resolve to one shared client")
    func sharedClientPerApp() throws {
        AIProxyAppAttestClient.resetSharedClients()
        defer { AIProxyAppAttestClient.resetSharedClients() }

        // configure holds the app URL; the services hold service URLs. Same app, same client.
        let a = try AIProxyAppAttestClient.shared(for: "https://api.aiproxy.com/dd6bcfd0")
        let b = try AIProxyAppAttestClient.shared(for: "https://api.aiproxy.com/dd6bcfd0/0ther5vc")
        let c = try AIProxyAppAttestClient.shared(for: "https://api.aiproxy.com/eeeeeeee/c27411bd")
        #expect(a === b)
        #expect(a !== c)
        #expect(AIProxyAppAttestClient.allShared.count == 2)
    }
}
