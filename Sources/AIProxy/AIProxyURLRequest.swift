//
//  AIProxyURLRequest.swift
//
//
//  Created by Lou Zell on 8/6/24.
//

import Foundation

@AIProxyActor enum AIProxyURLRequest {

    /// Creates a URLRequest that is configured for use with an AIProxy URLSession.
    /// Can raise `AIProxyError.deviceCheckIsUnavailable` or `AIProxyError.deviceCheckBypassIsMissing`
    /// (with `verificationMethod: .deviceCheck`), or the `AIProxyError.appAttest*` cases
    /// (with `verificationMethod: .appAttest`).
    static func create(
        partialKey: String,
        serviceURL: String,
        clientID: String?,
        proxyPath: String,
        body: Data?,
        verb: AIProxyHTTPVerb,
        secondsToWait: UInt,
        contentType: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> URLRequest {
        try await create(
            builder: AIProxyProxiedRequestBuilder(partialKey: partialKey, serviceURL: serviceURL, clientID: clientID),
            serviceURL: serviceURL,
            proxyPath: proxyPath,
            body: body,
            verb: verb,
            secondsToWait: secondsToWait,
            contentType: contentType,
            additionalHeaders: additionalHeaders
        )
    }

    static func create(
        builder: AIProxyProxiedRequestBuilder,
        serviceURL: String,
        proxyPath: String,
        body: Data?,
        verb: AIProxyHTTPVerb,
        secondsToWait: UInt,
        contentType: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) async throws -> URLRequest {
        let resolvedClientID = await getResolvedClientID(builder.clientID)
        var request = try URLRequest(serviceURL: serviceURL, proxyPath: proxyPath)
        request.networkServiceType = .avStreaming
        request.httpMethod = verb.toString(hasBody: body != nil)
        request.httpBody = body
        request.addValue(builder.partialKey, forHTTPHeaderField: "aiproxy-partial-key")
        request.addValue(resolvedClientID, forHTTPHeaderField: "aiproxy-client-id")

        request.addValue(
            await AIProxyUtils.metadataHeader(withBodySize: body?.count ?? 0),
            forHTTPHeaderField: "aiproxy-metadata"
        )

        if let resolvedAccount = AnonymousAccountStorage.resolvedAccount {
            request.addValue(resolvedAccount.uuid, forHTTPHeaderField: "aiproxy-anonymous-id")
        }

        if let contentType = contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        for (headerField, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: headerField)
        }

        request.timeoutInterval = TimeInterval(secondsToWait)

        // Verification goes last: an App Attest assertion covers the method, path, and
        // body, all of which are final by now.
        switch AIProxy.verificationMethod {
        case .deviceCheck:
            try await addDeviceCheckHeaders(to: &request, builder: builder, clientID: resolvedClientID)
        case .appAttest:
            // The service URL identifies the app; its client was created by `configure`.
            try await addAppAttestHeaders(to: &request, serviceURL: serviceURL, body: body)
        }

        return request
    }

    /// Can raise `AIProxyError.deviceCheckIsUnavailable` or `AIProxyError.deviceCheckBypassIsMissing`
    private static func addDeviceCheckHeaders(
        to request: inout URLRequest,
        builder: AIProxyProxiedRequestBuilder,
        clientID: String
    ) async throws {
    #if targetEnvironment(simulator)
        guard let deviceCheckBypass = ProcessInfo.processInfo.environment["AIPROXY_DEVICE_CHECK_BYPASS"] else {
            throw AIProxyError.deviceCheckBypassIsMissing
        }
        request.addValue(deviceCheckBypass, forHTTPHeaderField: "aiproxy-devicecheck-bypass")
    #else
        #if DEBUG
        let token = if let deviceCheckTokenProvider = builder.deviceCheckTokenProvider {
            await deviceCheckTokenProvider(clientID)
        } else {
            await AIProxyDeviceCheck.getToken(forClient: clientID)
        }
        #else
        let token = await AIProxyDeviceCheck.getToken(forClient: clientID)
        #endif
        guard let deviceCheckToken = token else {
            throw AIProxyError.deviceCheckIsUnavailable
        }
        request.addValue(deviceCheckToken, forHTTPHeaderField: "aiproxy-devicecheck")
    #endif
    }

    /// Signs the request with this install's App Attest key, or sends the Simulator bypass token.
    /// Can raise `AIProxyError.appAttestRequiresServiceURL`, `.appAttestBypassIsMissing`,
    /// `.appAttestIsUnavailable`, or a registration error on first use.
    private static func addAppAttestHeaders(to request: inout URLRequest, serviceURL: String, body: Data?) async throws {
        let bypass = ProcessInfo.processInfo.environment["AIPROXY_APP_ATTEST_BYPASS"]
    #if targetEnvironment(simulator)
        guard let bypass else {
            throw AIProxyError.appAttestBypassIsMissing
        }
        request.addValue(bypass, forHTTPHeaderField: AIProxyAppAttestHeaders.bypass)
    #else
        let client = try AIProxyAppAttestClient.shared(for: serviceURL)
        if client.isSupported {
            guard let url = request.url else {
                throw AIProxyError.assertion("Cannot sign a request that has no URL")
            }
            let headers = try await client.signatureHeaders(
                method: request.httpMethod ?? "GET",
                url: url,
                body: body
            )
            for (headerField, value) in headers {
                request.addValue(value, forHTTPHeaderField: headerField)
            }
        } else if let bypass {
            logIf(.info)?.info("AIProxy: App Attest is not supported on this device, using the bypass token")
            request.addValue(bypass, forHTTPHeaderField: AIProxyAppAttestHeaders.bypass)
        } else {
            throw AIProxyError.appAttestIsUnavailable
        }
    #endif
    }

    /// Creates a URLRequest that is intended for direct use with the service provider.
    /// WARNING: These requests are not protected by AIProxy's pk pinning, split key encryption, DeviceCheck, or rate limiting.
    static func createDirect(
        baseURL: String,
        path: String,
        body: Data?,
        verb: AIProxyHTTPVerb,
        secondsToWait: UInt,
        contentType: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) throws -> URLRequest {
        let url = try requestURL(
            baseURL: baseURL,
            path: path,
            componentsError: "Could not create urlComponents for the direct-to-provider use case"
        )

        var request = URLRequest(url: url)
        request.networkServiceType = .avStreaming
        request.httpMethod = verb.toString(hasBody: body != nil)
        request.httpBody = body

        if let contentType = contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        for (headerField, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: headerField)
        }

        request.timeoutInterval = TimeInterval(secondsToWait)
        return request
    }
}

nonisolated private func getResolvedClientID(_ clientID: String?) async -> String {
    if let clientID {
        return clientID
    }
    return await AIProxyIdentifier.getClientID()
}

private extension URLRequest {
    nonisolated init(serviceURL: String, proxyPath: String) throws {
        let url = try requestURL(
            baseURL: serviceURL,
            path: proxyPath,
            componentsError: "Could not create urlComponents, please check your AIProxy serviceURL constant"
        )

        self = Self(url: url)
    }
}

/// Joins encoded path data without turning escaped separators into route separators.
nonisolated private func requestURL(baseURL: String, path: String, componentsError: String) throws -> URL {
    let path = path.starts(with: "/") ? path : "/\(path)"
    guard var components = URLComponents(string: baseURL),
          let pathComponents = URLComponents(string: path) else {
        throw AIProxyError.assertion(componentsError)
    }
    components.percentEncodedPath += pathComponents.percentEncodedPath
    components.queryItems = pathComponents.queryItems
    guard let url = components.url else {
        throw AIProxyError.assertion("Could not create a request URL")
    }
    return url
}
