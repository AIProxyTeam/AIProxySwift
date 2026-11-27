import CryptoKit
import Foundation
import Network
import Security
import Testing

/// A throwaway, self-signed loopback identity. Only the test peer owns this key.
/// Generated with OpenSSL using a P-256 key and a self-signed localhost server certificate
/// (SAN 127.0.0.1, DNS localhost, validity January 2024). The DER values are public test data.
/// SecIdentityCreate constructs an in-memory identity without installing anything in a keychain.
enum RealtimeTLSFixture {
    /// Configure only this handshake, using a fixed date inside the fixture’s validity period.
    static func configureTrust(_ trust: SecTrust, trustFixture: Bool) -> OSStatus {
        if trustFixture {
            guard let certificate = try? certificate else { return errSecDecode }
            let status = SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
            guard status == errSecSuccess else { return status }
        }
        return SecTrustSetVerifyDate(trust, Date(timeIntervalSince1970: 1_705_276_800) as CFDate)
    }

    private static var certificate: SecCertificate {
        get throws {
            try #require(SecCertificateCreateWithData(nil, Data(base64Encoded: certificateDER)! as CFData))
        }
    }

    static func server(
        upgrade: RealtimeLoopbackServer.Upgrade = .accept,
        onlyTLSVersion: tls_protocol_version_t? = nil
    ) throws -> (peer: RealtimeLoopbackServer, publicKey: Data) {
        let key = try P256.Signing.PrivateKey(derRepresentation: Data(base64Encoded: privateKeyDER)!)
        let attributes = [kSecAttrKeyClass: kSecAttrKeyClassPrivate, kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom]
        let privateKey = try #require(SecKeyCreateWithData(key.x963Representation as CFData, attributes as CFDictionary, nil))
        let identity = try #require(SecIdentityCreate(nil, certificate, privateKey))
        let tls = NWProtocolTLS.Options()
        if let onlyTLSVersion {
            sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, onlyTLSVersion)
            sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, onlyTLSVersion)
        }
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, try #require(sec_identity_create(identity)))
        let parameters = NWParameters(tls: tls)
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        return (try RealtimeLoopbackServer(upgrade: upgrade, parameters: parameters), key.publicKey.x963Representation)
    }

    private static let certificateDER = "MIIBizCCATCgAwIBAgIEATTW5TAKBggqhkjOPQQDAjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjQwMjAxMDAwMDAwWjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATm69bIM+rf7AYWMjLbGwKqFasNLc4t5QelOiFCTKwovG9zWsm/8dRoeOlwyOH//+Ysi88hqQXiNKUaQi05nPoko3AwbjAdBgNVHQ4EFgQU79+FZJywKr7z99JKFVhKk8jvklgwGgYDVR0RBBMwEYcEfwAAAYIJbG9jYWxob3N0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDgYDVR0PAQH/BAQDAgeAMAoGCCqGSM49BAMCA0kAMEYCIQDzILLlc258RLLnEb8Ac7GVQefXufD2CFT2CGbAvlaIPAIhAI0YqSXBZMtNMyznfV5YWTH7koNDEsyfDR/RHss93+vt"
    private static let privateKeyDER = "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgsUYSbH/pXS7E2fIIRfA7ySiJwywVlrD/ePKYG8orZD6hRANCAATm69bIM+rf7AYWMjLbGwKqFasNLc4t5QelOiFCTKwovG9zWsm/8dRoeOlwyOH//+Ysi88hqQXiNKUaQi05nPok"
}
