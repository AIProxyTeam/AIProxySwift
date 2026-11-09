//
//  StandardComputeService.swift
//  AIProxy
//
//  Created by Henrik Bakke Dukefoss on 11/9/26.
//

import Foundation

@AIProxyActor public protocol StandardComputeService: Sendable {

    /// Initiates a non-streaming chat completion request to /v1/chat/completions.
    ///
    /// - Parameters:
    ///   - body: The request body to send to Standard Compute. Standard Compute's API is OpenAI compatible. See this reference:
    ///           https://docs.standardcompute.com
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    /// - Returns: The chat response. See this reference:
    ///            https://platform.openai.com/docs/api-reference/chat/object
    func chatCompletionRequest(
        body: OpenAIChatCompletionRequestBody,
        secondsToWait: UInt
    ) async throws -> OpenAIChatCompletionResponseBody

    /// Initiates a streaming chat completion request to /v1/chat/completions.
    ///
    /// - Parameters:
    ///   - body: The request body to send to Standard Compute. Standard Compute's API is OpenAI compatible. See this reference:
    ///           https://docs.standardcompute.com
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    /// - Returns: An async sequence of completion chunks. See this reference:
    ///            https://platform.openai.com/docs/api-reference/chat/streaming
    func streamingChatCompletionRequest(
        body: OpenAIChatCompletionRequestBody,
        secondsToWait: UInt
    ) async throws -> AsyncThrowingStream<OpenAIChatCompletionChunk, Error>
}

extension StandardComputeService {
    public func chatCompletionRequest(
        body: OpenAIChatCompletionRequestBody
    ) async throws -> OpenAIChatCompletionResponseBody {
        return try await self.chatCompletionRequest(body: body, secondsToWait: 60)
    }

    public func streamingChatCompletionRequest(
        body: OpenAIChatCompletionRequestBody
    ) async throws -> AsyncThrowingStream<OpenAIChatCompletionChunk, Error> {
        return try await self.streamingChatCompletionRequest(body: body, secondsToWait: 60)
    }
}
