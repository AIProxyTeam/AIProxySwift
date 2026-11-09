//
//  StandardComputeProxiedService.swift
//  AIProxy
//
//  Created by Henrik Bakke Dukefoss on 11/9/26.
//

import Foundation

@AIProxyActor final class StandardComputeProxiedService: StandardComputeService, ProxiedService, Sendable {
    private let partialKey: String
    private let serviceURL: String
    private let clientID: String?

    /// This initializer is not public on purpose.
    /// Customers are expected to use the factory `AIProxy.standardComputeService` defined in AIProxy.swift
    nonisolated init(
        partialKey: String,
        serviceURL: String,
        clientID: String?
    ) {
        self.partialKey = partialKey
        self.serviceURL = serviceURL
        self.clientID = clientID
    }

    /// Initiates a non-streaming chat completion request to /v1/chat/completions.
    ///
    /// - Parameters:
    ///   - body: The request body to send to Standard Compute, protected through AIProxy. Standard Compute's API is OpenAI compatible. See this reference:
    ///           https://docs.standardcompute.com
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    /// - Returns: The chat response. See this reference:
    ///            https://platform.openai.com/docs/api-reference/chat/object
    public func chatCompletionRequest(
        body: OpenAIChatCompletionRequestBody,
        secondsToWait: UInt
    ) async throws -> OpenAIChatCompletionResponseBody {
        var body = body
        body.stream = false
        body.streamOptions = nil
        let request = try await AIProxyURLRequest.create(
            partialKey: self.partialKey,
            serviceURL: self.serviceURL,
            clientID: self.clientID,
            proxyPath: "/v1/chat/completions",
            body: try body.serialize(),
            verb: .post,
            secondsToWait: secondsToWait,
            contentType: "application/json",
            additionalHeaders: [
                "Accept": "application/json"
            ]
        )
        return try await self.makeRequestAndDeserializeResponse(request)
    }

    /// Initiates a streaming chat completion request to /v1/chat/completions.
    ///
    /// - Parameters:
    ///   - body: The request body to send to Standard Compute, protected through AIProxy. Standard Compute's API is OpenAI compatible. See this reference:
    ///           https://docs.standardcompute.com
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    /// - Returns: An async sequence of completion chunks. See this reference:
    ///            https://platform.openai.com/docs/api-reference/chat/streaming
    public func streamingChatCompletionRequest(
        body: OpenAIChatCompletionRequestBody,
        secondsToWait: UInt
    ) async throws -> AsyncThrowingStream<OpenAIChatCompletionChunk, Error> {
        var body = body
        body.stream = true
        body.streamOptions = .init(includeUsage: true)
        let request = try await AIProxyURLRequest.create(
            partialKey: self.partialKey,
            serviceURL: self.serviceURL,
            clientID: self.clientID,
            proxyPath: "/v1/chat/completions",
            body: try body.serialize(),
            verb: .post,
            secondsToWait: secondsToWait,
            contentType: "application/json",
            additionalHeaders: [
                "Accept": "application/json"
            ]
        )
        return try await self.makeRequestAndDeserializeStreamingChunks(request)
    }
}
