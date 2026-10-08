//
//  AIProxyAppAttestClient.swift
//  AIProxy
//
//  Apple App Attest against AIProxy. Attests this install once with Apple and
//  AIProxy, then signs each request with a per-request assertion. See
//  https://www.aiproxy.com/docs/build-your-own-client.html#app-attest for the
//  wire contract this implements.
//

import Foundation

/// Attests this install once and signs requests for services whose
/// verification method is App Attest.
///
/// You do not normally use this type directly: set `verificationMethod: .appAttest`
/// in `AIProxy.configure` and every request the SDK builds is signed. It is public
/// so that apps with their own networking can sign requests too:
///
/// ```swift
/// let attest = try AIProxyAppAttestClient.shared(for: "https://api.aiproxy.com/<project>/<service>")
/// try await attest.attestIfNeeded()          // at launch, a few seconds once per install
/// var request = URLRequest(url: …)
/// request.httpMethod = "POST"; request.httpBody = body
/// try await attest.sign(&request)            // adds the four aiproxy-appattest-* headers
/// ```
///
/// One key per app: every service under the same host and AIProxy app shares
/// the key and the one-time attestation, and registration goes to the app's
/// own route, `/<project>/aiproxy/v1/attest/...`, so no service is involved.
/// The key ID is stored in the Keychain under the same service and account
/// that AIProxy's other Swift packages use, so mixing packages in one app
/// still attests once.
///
/// Registration failures back off, and a key Apple reports as invalid is
/// forgotten and re-attested once. Errors are `AIProxyError` cases carrying
/// the HTTP status and body where the server was involved.
public actor AIProxyAppAttestClient {

    /// Scheme, host, and port of the AIProxy deployment, for example `https://api.aiproxy.com`.
    nonisolated public let host: URL
    nonisolated public let projectID: String
    /// Namespaces the stored key: `<host>#<project id>`.
    nonisolated public let scope: String

    private let attestation: any AIProxyAttestationService
    private let store: any AIProxyAppAttestKeyStore
    private let transport: any AIProxyAppAttestHTTPTransport
    private let now: @Sendable () -> Date
    private let makeNonce: @Sendable () -> String
    private let clientID: @Sendable () async -> String

    private var cachedKeyID: String?
    private var registrationInFlight: Task<String, any Error>?
    private var backoff: (until: Date, cause: String)?

    private static let registrationBackoff: TimeInterval = 60
    private static let registrationQuotaBackoff: TimeInterval = 900

    // MARK: - Shared clients

    /// The client for an AIProxy app, shared by every service under the same
    /// host and app in this process.
    ///
    /// - Parameter url: The app URL from the dashboard, `https://host/<app>`, or any
    ///   of its service URLs, `https://host/<app>/<service>`; only the app segment is used.
    /// - Throws: `AIProxyError.appAttestRequiresServiceURL` when the URL has no app segment.
    public static func shared(for url: String) throws -> AIProxyAppAttestClient {
        let parsed = try parseAppURL(url)
        let scope = "\(parsed.host.absoluteString)#\(parsed.projectID)"
        return sharedClient(scope: scope) {
            AIProxyAppAttestClient(
                host: parsed.host,
                projectID: parsed.projectID,
                scope: scope,
                attestation: AIProxyDeviceAttestationService(),
                store: AIProxyKeychainAppAttestKeyStore(),
                transport: AIProxyURLSessionAppAttestTransport(session: AIProxyUtils.proxiedURLSession())
            )
        }
    }

    /// Starts the one-time attestation for an app in the background, so it
    /// lands at launch rather than on the user's first request. `AIProxy.configure`
    /// calls this with the app URL. Failures are logged; the first request retries.
    nonisolated static func warmUp(appURL: String) {
        guard let client = try? shared(for: appURL) else {
            logIf(.error)?.error("AIProxy: the App Attest appURL is not an AIProxy app URL (expected https://api.aiproxy.com/<app>): \(appURL)")
            return
        }
        guard client.isSupported else { return }
        Task {
            do {
                try await client.attestIfNeeded()
            } catch {
                logIf(.warning)?.warning("AIProxy: App Attest warm-up did not complete; the first request will attest: \(error.localizedDescription)")
            }
        }
    }

    /// Every client created so far in this process, one per AIProxy app.
    nonisolated static var allShared: [AIProxyAppAttestClient] {
        sharedClientsLock.lock()
        defer { sharedClientsLock.unlock() }
        return Array(sharedClients.values)
    }

    nonisolated(unsafe) private static var sharedClients: [String: AIProxyAppAttestClient] = [:]
    private static let sharedClientsLock = NSLock()

    static func sharedClient(scope: String, make: () -> AIProxyAppAttestClient) -> AIProxyAppAttestClient {
        sharedClientsLock.lock()
        defer { sharedClientsLock.unlock() }
        if let existing = sharedClients[scope] {
            return existing
        }
        let client = make()
        sharedClients[scope] = client
        return client
    }

    /// Tests use this to drop every shared client.
    static func resetSharedClients() {
        sharedClientsLock.lock()
        defer { sharedClientsLock.unlock() }
        sharedClients = [:]
    }

    /// Splits an app URL (`https://host/<app>`) or a service URL
    /// (`https://host/<app>/<service>`) into the deployment host and the app id.
    /// Attestation never uses the service segment.
    static func parseAppURL(_ url: String) throws -> (host: URL, projectID: String) {
        guard
            let components = URLComponents(string: url),
            let scheme = components.scheme,
            let hostName = components.host
        else {
            throw AIProxyError.appAttestRequiresServiceURL
        }

        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard (1...2).contains(segments.count) else {
            throw AIProxyError.appAttestRequiresServiceURL
        }

        var hostComponents = URLComponents()
        hostComponents.scheme = scheme
        hostComponents.host = hostName
        hostComponents.port = components.port
        guard let host = hostComponents.url else {
            throw AIProxyError.appAttestRequiresServiceURL
        }
        return (host, String(segments[0]))
    }

    // MARK: - Init

    init(
        host: URL,
        projectID: String,
        scope: String,
        attestation: any AIProxyAttestationService,
        store: any AIProxyAppAttestKeyStore,
        transport: any AIProxyAppAttestHTTPTransport,
        now: @escaping @Sendable () -> Date = { Date() },
        makeNonce: @escaping @Sendable () -> String = { AIProxyAppAttestSigning.randomNonce() },
        clientID: @escaping @Sendable () async -> String = { await AIProxyIdentifier.getClientID() }
    ) {
        self.host = host
        self.projectID = projectID
        self.scope = scope
        self.attestation = attestation
        self.store = store
        self.transport = transport
        self.now = now
        self.makeNonce = makeNonce
        self.clientID = clientID
    }

    // MARK: - Public API

    /// False on the Simulator and on hardware without a Secure Enclave. When
    /// false, the SDK falls back to the `AIPROXY_APP_ATTEST_BYPASS` token.
    public nonisolated var isSupported: Bool {
        attestation.isSupported
    }

    /// Idempotent. On a fresh install this generates a Secure Enclave key,
    /// attests it with Apple (a few seconds, rate limited by Apple), and
    /// registers it with AIProxy. Call at launch so the cost and any failure
    /// land before the user's first request.
    public func attestIfNeeded() async throws {
        _ = try await ensureKeyID()
    }

    /// The four `aiproxy-appattest-*` headers for a request. The assertion
    /// covers `method`, the percent-encoded path of `url` without its query
    /// string, `body`, a fresh nonce, the timestamp, and the key ID, so the
    /// server can verify it with no extra round trip. Sign after the body is
    /// final.
    public func signatureHeaders(method: String, url: URL, body: Data?) async throws -> [String: String] {
        let keyID = try await ensureKeyID()
        let path = AIProxyAppAttestSigning.signedPath(of: url)
        let body = body ?? Data()
        let nonce = makeNonce()
        let timestamp = Int(now().timeIntervalSince1970)

        let assertion: Data
        let signingKeyID: String
        do {
            assertion = try await attestation.generateAssertion(
                keyID,
                clientDataHash: AIProxyAppAttestSigning.clientDataHash(
                    method: method, path: path, body: body, nonce: nonce, timestamp: timestamp, keyID: keyID
                )
            )
            signingKeyID = keyID
        } catch is AIProxyAttestationKeyInvalid {
            logIf(.warning)?.warning("AIProxy: App Attest key rejected by Apple; forgetting it and re-attesting")
            try forgetKey()
            let replacement: String
            do {
                replacement = try await ensureKeyID()
            } catch {
                throw AIProxyError.appAttestKeyInvalidated
            }
            do {
                assertion = try await attestation.generateAssertion(
                    replacement,
                    clientDataHash: AIProxyAppAttestSigning.clientDataHash(
                        method: method, path: path, body: body, nonce: nonce, timestamp: timestamp, keyID: replacement
                    )
                )
            } catch is AIProxyAttestationKeyInvalid {
                throw AIProxyError.appAttestKeyInvalidated
            }
            signingKeyID = replacement
        }

        return [
            AIProxyAppAttestHeaders.keyID: signingKeyID,
            AIProxyAppAttestHeaders.assertion: assertion.base64EncodedString(),
            AIProxyAppAttestHeaders.nonce: nonce,
            AIProxyAppAttestHeaders.timestamp: String(timestamp),
        ]
    }

    /// Adds the four `aiproxy-appattest-*` headers to `request`. Set the
    /// method and body first; the assertion covers both.
    public func sign(_ request: inout URLRequest) async throws {
        guard let url = request.url else {
            throw AIProxyError.assertion("Cannot sign a URLRequest that has no URL")
        }
        let headers = try await signatureHeaders(method: request.httpMethod ?? "GET", url: url, body: request.httpBody)
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    /// Forgets the stored key so the next call attests again. The SDK calls
    /// this when AIProxy answers `app_attest_unknown_key`.
    public func reset() throws {
        try forgetKey()
        backoff = nil
    }

    // MARK: - Reacting to server rejections

    /// Called by the networking layer on every non-2xx AIProxy response. When
    /// the body says the key is unknown to AIProxy, the shared client for that
    /// request's app forgets it so the next request re-attests.
    nonisolated static func noteRejection(responseBody: String, requestURL: URL?) {
        guard
            responseBody.contains("app_attest_unknown_key"),
            let data = responseBody.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            error["type"] as? String == "app_attest_unknown_key",
            let requestURL,
            let parsed = try? parseAppURL(serviceURLPrefix(of: requestURL))
        else {
            return
        }

        let scope = "\(parsed.host.absoluteString)#\(parsed.projectID)"
        sharedClientsLock.lock()
        let client = sharedClients[scope]
        sharedClientsLock.unlock()

        guard let client else { return }
        logIf(.warning)?.warning("AIProxy: this device's App Attest key is unknown to AIProxy; it will attest again on the next request")
        Task {
            try? await client.reset()
        }
    }

    /// `https://host/<project>/<service>` from any request URL under it.
    private static func serviceURLPrefix(of url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        components.path = "/" + segments.prefix(2).joined(separator: "/")
        components.query = nil
        components.fragment = nil
        return components.url?.absoluteString ?? url.absoluteString
    }

    // MARK: - Registration

    private func ensureKeyID() async throws -> String {
        if let cachedKeyID {
            return cachedKeyID
        }
        if let stored = try store.keyID(for: scope) {
            cachedKeyID = stored
            return stored
        }
        if let registrationInFlight {
            return try await registrationInFlight.value
        }
        let task = Task { try await createAndRegisterKey() }
        registrationInFlight = task
        defer {
            if registrationInFlight == task {
                registrationInFlight = nil
            }
        }
        return try await task.value
    }

    private func createAndRegisterKey() async throws -> String {
        guard attestation.isSupported else {
            throw AIProxyError.appAttestIsUnavailable
        }
        if let backoff, backoff.until > now() {
            throw AIProxyError.appAttestRegistrationBackingOff(until: backoff.until, cause: backoff.cause)
        }
        backoff = nil

        let keyID = try await attestation.generateKey()
        do {
            let challenge = try await fetchChallenge(keyID: keyID)
            let attestationObject = try await attestation.attestKey(
                keyID,
                clientDataHash: AIProxyAppAttestSigning.registrationClientDataHash(challenge: challenge)
            )
            try await register(keyID: keyID, attestationObject: attestationObject)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let delay: TimeInterval
            if case AIProxyError.appAttestRegistrationFailed(429, _, let retryAfter) = error {
                delay = retryAfter ?? Self.registrationQuotaBackoff
            } else {
                delay = Self.registrationBackoff
            }
            backoff = (now().addingTimeInterval(delay), String(describing: error))
            logIf(.error)?.error("AIProxy: App Attest registration failed, backing off \(Int(delay))s: \(error)")
            throw error
        }

        cachedKeyID = keyID
        try store.setKeyID(keyID, for: scope)
        logIf(.info)?.info("AIProxy: App Attest key registered for \(self.scope)")
        return keyID
    }

    private func forgetKey() throws {
        cachedKeyID = nil
        try store.deleteKeyID(for: scope)
    }

    // MARK: - Attestation round trips

    private struct ChallengeResponse: Decodable {
        let challenge: String
        enum CodingKeys: String, CodingKey {
            case challenge
        }
    }

    private func fetchChallenge(keyID: String) async throws -> Data {
        let body = try JSONEncoder().encode(["key_id": keyID])
        let (data, http) = try await post(route: "aiproxy/v1/attest/challenge", body: body)
        try Self.requireSuccess(http, data: data)
        guard
            let response = try? JSONDecoder().decode(ChallengeResponse.self, from: data),
            let challenge = Data(base64Encoded: response.challenge),
            !challenge.isEmpty
        else {
            throw AIProxyError.appAttestMalformedResponse(route: "challenge")
        }
        return challenge
    }

    private func register(keyID: String, attestationObject: Data) async throws {
        let body = try JSONEncoder().encode([
            "key_id": keyID,
            "attestation_object": attestationObject.base64EncodedString(),
        ])
        let (data, http) = try await post(route: "aiproxy/v1/attest/register", body: body)
        try Self.requireSuccess(http, data: data)
    }

    // The attest routes are per app: `/<project>/aiproxy/v1/attest/{challenge,register}`.
    private func post(route: String, body: Data) async throws -> (Data, HTTPURLResponse) {
        let url = host
            .appendingPathComponent(projectID)
            .appendingPathComponent(route)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(await clientID(), forHTTPHeaderField: "aiproxy-client-id")
        request.setValue(
            await AIProxyUtils.metadataHeader(withBodySize: body.count),
            forHTTPHeaderField: "aiproxy-metadata"
        )
        request.httpBody = body
        return try await transport.data(for: request)
    }

    private static func requireSuccess(_ http: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(http.statusCode) else { return }
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
        throw AIProxyError.appAttestRegistrationFailed(
            statusCode: http.statusCode,
            responseBody: String(decoding: data.prefix(2048), as: UTF8.self),
            retryAfter: retryAfter
        )
    }
}
