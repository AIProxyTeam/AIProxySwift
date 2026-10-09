//
//  MistralService.swift
//
//
//  Created by Lou Zell on 12/19/24.
//

import Foundation

@AIProxyActor public class MistralService: Sendable {
    private let requestBuilder: AIProxyRequestBuilder
    private let serviceNetworker: ServiceMixin

    /// This designated initializer is not public on purpose.
    /// Customers are expected to use the factory `AIProxy.mistralService` or `AIProxy.mistralDirectService` defined in AIProxy.swift.
    nonisolated init(
        requestBuilder: AIProxyRequestBuilder,
        serviceNetworker: ServiceMixin
    ) {
        self.requestBuilder = requestBuilder
        self.serviceNetworker = serviceNetworker
    }

    /// Initiates a non-streaming chat completion request to Mistral
    ///
    /// - Parameters:
    ///   - body: The chat completion request body. See this reference:
    ///           https://docs.mistral.ai/api/#tag/chat/operation/chat_completion_v1_chat_completions_post
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    ///   - additionalHeaders: Optional headers to pass up with the request alongside the lib's default headers
    /// - Returns: A ChatCompletionResponse.
    public func chatCompletionRequest(
        body: MistralChatCompletionRequestBody,
        secondsToWait: UInt,
        additionalHeaders: [String: String] = [:]
    ) async throws -> MistralChatCompletionResponseBody {
        var body = body
        body.stream = false
        let request = try await self.requestBuilder.jsonPOST(
            path: "/v1/chat/completions",
            body: body,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
        return try await self.serviceNetworker.makeRequestAndDeserializeResponse(request)
    }

    /// Initiates a streaming chat completion request to Mistral.
    ///
    /// - Parameters:
    ///   - body: The chat completion request body. See this reference:
    ///           https://docs.mistral.ai/api/#tag/chat/operation/chat_completion_v1_chat_completions_post
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    ///   - additionalHeaders: Optional headers to pass up with the request alongside the lib's default headers
    /// - Returns: An async sequence of completion chunks. See this reference:
    ///            https://platform.openai.com/docs/api-reference/chat/streaming
    public func streamingChatCompletionRequest(
        body: MistralChatCompletionRequestBody,
        secondsToWait: UInt,
        additionalHeaders: [String: String] = [:]
    ) async throws -> AsyncThrowingStream<MistralChatCompletionStreamingChunk, Error> {
        var body = body
        body.stream = true
        let request = try await self.requestBuilder.jsonPOST(
            path: "/v1/chat/completions",
            body: body,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
        return try await self.serviceNetworker.makeRequestAndDeserializeStreamingChunks(request)
    }

    /// Initiates an OCR request to Mistral
    ///
    /// - Parameters:
    ///   - body: The OCR request body. See this reference:
    ///           https://docs.mistral.ai/api/#tag/ocr/operation/ocr_v1_ocr_post
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    ///   - additionalHeaders: Optional headers to pass up with the request alongside the lib's default headers
    /// - Returns: The OCR result
    public func ocrRequest(
        body: MistralOCRRequestBody,
        secondsToWait: UInt,
        additionalHeaders: [String: String] = [:]
    ) async throws -> MistralOCRResponseBody {
        let request = try await self.requestBuilder.jsonPOST(
            path: "/v1/ocr",
            body: body,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
        return try await self.serviceNetworker.makeRequestAndDeserializeResponse(request)
    }

    /// Initiates a transcription request to `/v1/audio/transcriptions`
    ///
    /// - Parameters:
    ///   - body: The audio transcription request body. See this reference:
    ///           https://docs.mistral.ai/api/endpoint/audio/transcriptions#operation-audio_api_v1_transcriptions_post
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    ///   - additionalHeaders: Optional headers to pass up with the request alongside the lib's default headers
    /// - Returns: A transcription response. See this reference:
    ///            https://docs.mistral.ai/api/endpoint/audio/transcriptions#operation-audio_api_v1_transcriptions_post
    public func createTranscriptionRequest(
        body: MistralTranscriptionRequestBody,
        secondsToWait: UInt,
        additionalHeaders: [String: String] = [:]
    ) async throws -> MistralTranscriptionResponseBody {
        var body = body
        body.stream = false
        let request = try await self.requestBuilder.multipartPOST(
            path: "/v1/audio/transcriptions",
            body: body,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
        return try await self.serviceNetworker.makeRequestAndDeserializeResponse(request)
    }

    /// Initiates a streaming transcription request to `/v1/audio/transcriptions`.
    ///
    /// - Parameters:
    ///   - body: The audio transcription request body. `stream` is set to true by this method.
    ///           See: https://docs.mistral.ai/api/endpoint/audio/transcriptions#operation-audio_api_v1_transcriptions_post_stream
    ///   - secondsToWait: The amount of time to wait before `URLError.timedOut` is raised
    ///   - additionalHeaders: Optional headers to pass up with the request alongside the lib's default headers
    /// - Returns: An async sequence of transcription stream events.
    public func streamingTranscriptionRequest(
        body: MistralTranscriptionRequestBody,
        secondsToWait: UInt,
        additionalHeaders: [String: String] = [:]
    ) async throws -> AsyncThrowingStream<MistralTranscriptionStreamingEvent, Error> {
        var body = body
        body.stream = true
        let request = try await self.requestBuilder.multipartPOST(
            path: "/v1/audio/transcriptions",
            body: body,
            secondsToWait: secondsToWait,
            additionalHeaders: additionalHeaders
        )
        return try await self.serviceNetworker.makeRequestAndDeserializeStreamingChunks(request)
    }
}
