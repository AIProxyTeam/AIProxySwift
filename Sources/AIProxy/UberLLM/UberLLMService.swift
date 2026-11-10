//
//  UberLLMService.swift
//  AIProxy
//
//  Created by PSA-Team-source on 11/10/26.
//

import Foundation

@AIProxyActor public protocol UberLLMService: Sendable {

    /// Initiates a non-streaming chat completion request to /v1/chat/completions.
    ///
    /// - Parameters:
    ///   - body: The request body to send to UberLLM. UberLLM's API is OpenAI compatible. See this reference:
    ///           https://uberllm.dev/docs
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
    ///   - body: The request body to send to UberLLM. UberLLM's API is OpenAI compatible. See this reference:
    ///           https://uberllm.dev/docs
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    /// - Returns: An async sequence of completion chunks. See this reference:
    ///            https://platform.openai.com/docs/api-reference/chat/streaming
    func streamingChatCompletionRequest(
        body: OpenAIChatCompletionRequestBody,
        secondsToWait: UInt
    ) async throws -> AsyncThrowingStream<OpenAIChatCompletionChunk, Error>
}

extension UberLLMService {
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
