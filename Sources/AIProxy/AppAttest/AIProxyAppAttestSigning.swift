//
//  AIProxyAppAttestSigning.swift
//  AIProxy
//
//  The wire contract between an attested app and AIProxy.
//  Documented at https://www.aiproxy.com/docs/build-your-own-client.html#app-attest
//

import Foundation
import CryptoKit

/// Headers that carry an App Attest assertion to AIProxy.
///
/// Every request to a service whose verification method is App Attest carries
/// the first four. The server recomputes the client data hash from the request
/// it received and verifies the assertion against the public key registered
/// for `keyID`.
nonisolated public enum AIProxyAppAttestHeaders {
    /// Base64 App Attest key ID, as returned by `DCAppAttestService.generateKey()`.
    public static let keyID = "aiproxy-appattest-key-id"
    /// Base64 CBOR assertion from `DCAppAttestService.generateAssertion`.
    public static let assertion = "aiproxy-appattest-assertion"
    /// Base64 of 16 random bytes, unique per request. The server rejects reuse.
    public static let nonce = "aiproxy-appattest-nonce"
    /// Unix seconds at signing time. The server rejects values more than 300 seconds from its clock.
    public static let timestamp = "aiproxy-appattest-timestamp"
    /// The Simulator bypass token from the app's App Attest configuration. Development only.
    public static let bypass = "aiproxy-appattest-bypass"
}

nonisolated enum AIProxyAppAttestSigning {
    static let version = "aiproxy-appattest-v1"

    /// The client data hash an assertion signs, version 1:
    ///
    ///     SHA256(version || "\n" || method || "\n" || path || "\n"
    ///            || SHA256(body) || "\n" || nonce_b64 || "\n" || timestamp || "\n" || key_id)
    ///
    /// `SHA256(body)` is inserted as its 32 raw bytes, not hex. `path` is the
    /// percent-encoded path without the query string. `timestamp` is decimal
    /// unix seconds. This must stay byte-identical to `Eproxy.AppAttest.client_data_hash/6`.
    static func clientDataHash(
        method: String,
        path: String,
        body: Data,
        nonce: String,
        timestamp: Int,
        keyID: String
    ) -> Data {
        var hash = SHA256()
        hash.update(data: Data(version.utf8))
        hash.update(data: Data("\n".utf8))
        hash.update(data: Data(method.utf8))
        hash.update(data: Data("\n".utf8))
        hash.update(data: Data(path.utf8))
        hash.update(data: Data("\n".utf8))
        hash.update(data: Data(SHA256.hash(data: body)))
        hash.update(data: Data("\n".utf8))
        hash.update(data: Data(nonce.utf8))
        hash.update(data: Data("\n".utf8))
        hash.update(data: Data(String(timestamp).utf8))
        hash.update(data: Data("\n".utf8))
        hash.update(data: Data(keyID.utf8))
        return Data(hash.finalize())
    }

    /// The client data hash used during registration: SHA256 of the raw
    /// challenge bytes. eproxy expects the attestation nonce to be
    /// `SHA256(authData || SHA256(challenge))`.
    static func registrationClientDataHash(challenge: Data) -> Data {
        Data(SHA256.hash(data: challenge))
    }

    /// Base64 of 16 bytes from the system's cryptographically secure generator.
    static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in bytes.indices {
            bytes[i] = UInt8.random(in: .min ... .max)
        }
        return Data(bytes).base64EncodedString()
    }

    /// The path the assertion covers: percent-encoded, without the query
    /// string or fragment, exactly as AIProxy sees it.
    static func signedPath(of url: URL) -> String {
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? url.path
        return path.isEmpty ? "/" : path
    }
}
