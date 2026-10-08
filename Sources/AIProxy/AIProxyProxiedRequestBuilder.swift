//
//  AIProxyProxiedRequestBuilder.swift
//  AIProxy
//
//  Created by Lou Zell on 7/12/25.
//

import Foundation

nonisolated private let legacyURL = "https://api.aiproxy.pro"

@AIProxyActor struct AIProxyProxiedRequestBuilder: AIProxyRequestBuilder {
    let partialKey: String
    let serviceURL: String?
    let clientID: String?
    #if DEBUG
    // Per-builder override for deterministic tests; excluded from release builds.
    let deviceCheckTokenProvider: (@AIProxyActor @Sendable (String?) async -> String?)?
    #endif

    nonisolated init(
        partialKey: String,
        serviceURL: String?,
        clientID: String?
    ) {
        self.partialKey = partialKey
        self.serviceURL = serviceURL
        self.clientID = clientID
        #if DEBUG
        self.deviceCheckTokenProvider = nil
        #endif
    }

    #if DEBUG
    nonisolated init(
        partialKey: String,
        serviceURL: String?,
        clientID: String?,
        deviceCheckTokenProvider: @escaping @AIProxyActor @Sendable (String?) async -> String?
    ) {
        self.partialKey = partialKey
        self.serviceURL = serviceURL
        self.clientID = clientID
        self.deviceCheckTokenProvider = deviceCheckTokenProvider
    }
    #endif

    func jsonPOST(
        path: String,
        body: Encodable,
        secondsToWait: UInt,
        additionalHeaders: [String: String],
        baseURLOverride permittedUpstream: String?
    ) async throws -> URLRequest {
        var additionalHeaders = additionalHeaders
        if let permittedUpstream {
            additionalHeaders["aiproxy-permitted-upstream"] = permittedUpstream
        }
        return try await AIProxyURLRequest.create(
            builder: self,
            serviceURL: self.serviceURL ?? legacyURL,
            proxyPath: path,
            body: try body.serialize(),
            verb: .post,
            secondsToWait: secondsToWait,
            contentType: "application/json",
            additionalHeaders: additionalHeaders
        )
    }

    func multipartPOST(
        path: String,
        body: MultipartFormEncodable,
        secondsToWait: UInt,
        additionalHeaders: [String : String],
        baseURLOverride permittedUpstream: String?
    ) async throws -> URLRequest {
        var additionalHeaders = additionalHeaders
        if let permittedUpstream {
            additionalHeaders["aiproxy-permitted-upstream"] = permittedUpstream
        }
        let boundary = UUID().uuidString
        return try await AIProxyURLRequest.create(
            builder: self,
            serviceURL: self.serviceURL ?? legacyURL,
            proxyPath: path,
            body: formEncode(body, boundary),
            verb: .post,
            secondsToWait: secondsToWait,
            contentType: "multipart/form-data; boundary=\(boundary)",
            additionalHeaders: additionalHeaders
        )
    }

    func plainGET(
        path: String,
        secondsToWait: UInt,
        additionalHeaders: [String : String],
        baseURLOverride permittedUpstream: String?
    ) async throws -> URLRequest {
        var additionalHeaders = additionalHeaders
        if let permittedUpstream {
            additionalHeaders["aiproxy-permitted-upstream"] = permittedUpstream
        }
        return try await AIProxyURLRequest.create(
            builder: self,
            serviceURL: self.serviceURL ?? legacyURL,
            proxyPath: path,
            body: nil,
            verb: .get,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
    }

    func plainDELETE(
        path: String,
        secondsToWait: UInt,
        additionalHeaders: [String : String],
        baseURLOverride permittedUpstream: String?
    ) async throws -> URLRequest {
        var additionalHeaders = additionalHeaders
        if let permittedUpstream {
            additionalHeaders["aiproxy-permitted-upstream"] = permittedUpstream
        }
        return try await AIProxyURLRequest.create(
            builder: self,
            serviceURL: self.serviceURL ?? legacyURL,
            proxyPath: path,
            body: nil,
            verb: .delete,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
    }
}
