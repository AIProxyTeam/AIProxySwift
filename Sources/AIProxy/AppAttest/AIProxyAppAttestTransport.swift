//
//  AIProxyAppAttestTransport.swift
//  AIProxy
//

import Foundation

/// The two attestation round trips (challenge and register), behind a
/// protocol so tests can script the server.
nonisolated protocol AIProxyAppAttestHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

nonisolated struct AIProxyURLSessionAppAttestTransport: AIProxyAppAttestHTTPTransport {
    let session: URLSession

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(
            for: request,
            delegate: session.delegate as? URLSessionTaskDelegate
        )
        guard let http = response as? HTTPURLResponse else {
            throw AIProxyError.assertion("App Attest registration response is not an HTTP response")
        }
        return (data, http)
    }
}
