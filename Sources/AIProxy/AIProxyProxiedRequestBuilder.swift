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
            partialKey: self.partialKey,
            serviceURL: self.serviceURL ?? legacyURL,
            clientID: self.clientID,
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
            partialKey: self.partialKey,
            serviceURL: self.serviceURL ?? legacyURL,
            clientID: self.clientID,
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
            partialKey: self.partialKey,
            serviceURL: self.serviceURL ?? legacyURL,
            clientID: self.clientID,
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
            partialKey: self.partialKey,
            serviceURL: self.serviceURL ?? legacyURL,
            clientID: self.clientID,
            proxyPath: path,
            body: nil,
            verb: .delete,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
    }
}
