//
//  AIProxyAttestationService.swift
//  AIProxy
//

import Foundation
#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// The subset of `DCAppAttestService` the client needs, behind a protocol so
/// tests can run without a Secure Enclave.
nonisolated protocol AIProxyAttestationService: Sendable {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

/// Thrown by `generateAssertion` when Apple reports the key as invalid, so the
/// client can forget it and attest again.
nonisolated struct AIProxyAttestationKeyInvalid: Error, Sendable {}

#if canImport(DeviceCheck)
nonisolated struct AIProxyDeviceAttestationService: AIProxyAttestationService {
    var isSupported: Bool {
        DCAppAttestService.shared.isSupported
    }

    func generateKey() async throws -> String {
        try await DCAppAttestService.shared.generateKey()
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        do {
            return try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
        } catch let error as DCError where error.code == .invalidKey {
            throw AIProxyAttestationKeyInvalid()
        }
    }
}
#else
nonisolated struct AIProxyDeviceAttestationService: AIProxyAttestationService {
    var isSupported: Bool { false }
    func generateKey() async throws -> String { throw AIProxyError.appAttestIsUnavailable }
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data { throw AIProxyError.appAttestIsUnavailable }
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data { throw AIProxyError.appAttestIsUnavailable }
}
#endif
