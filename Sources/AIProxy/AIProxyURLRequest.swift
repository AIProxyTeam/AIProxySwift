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
    static func create(
        partialKey: String,
        serviceURL: String,
        clientID: String?,
        proxyPath: String,
        body: Data?,
        verb: AIProxyHTTPVerb,
        secondsToWait: UInt,
        contentType: String? = nil,
        additionalHeaders: [String: String] = [:],
        deviceCheckTokenProvider: (@AIProxyActor @Sendable (String?) async -> String?)? = nil
    ) async throws -> URLRequest {
        let resolvedClientID = await getResolvedClientID(clientID)
        var request = try URLRequest(serviceURL: serviceURL, proxyPath: proxyPath)
        request.networkServiceType = .avStreaming
        request.httpMethod = verb.toString(hasBody: body != nil)
        request.httpBody = body
        request.addValue(partialKey, forHTTPHeaderField: "aiproxy-partial-key")
        request.addValue(resolvedClientID, forHTTPHeaderField: "aiproxy-client-id")

        request.addValue(
            await AIProxyUtils.metadataHeader(withBodySize: body?.count ?? 0),
            forHTTPHeaderField: "aiproxy-metadata"
        )

        if let resolvedAccount = AnonymousAccountStorage.resolvedAccount {
            request.addValue(resolvedAccount.uuid, forHTTPHeaderField: "aiproxy-anonymous-id")
        }

    #if targetEnvironment(simulator)
        guard let deviceCheckBypass = ProcessInfo.processInfo.environment["AIPROXY_DEVICE_CHECK_BYPASS"] else {
            throw AIProxyError.deviceCheckBypassIsMissing
        }
        request.addValue(deviceCheckBypass, forHTTPHeaderField: "aiproxy-devicecheck-bypass")
    #else
        let token = if let deviceCheckTokenProvider {
            await deviceCheckTokenProvider(resolvedClientID)
        } else {
            await AIProxyDeviceCheck.getToken(forClient: resolvedClientID)
        }
        guard let deviceCheckToken = token else {
            throw AIProxyError.deviceCheckIsUnavailable
        }
        request.addValue(deviceCheckToken, forHTTPHeaderField: "aiproxy-devicecheck")
    #endif

        if let contentType = contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        for (headerField, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: headerField)
        }

        request.timeoutInterval = TimeInterval(secondsToWait)
        return request
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
