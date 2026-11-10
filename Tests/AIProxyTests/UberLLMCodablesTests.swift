//
//  UberLLMCodablesTests.swift
//  AIProxy
//
//  Created by PSA-Team-source on 11/10/26.
//

import XCTest
@testable import AIProxy

final class UberLLMCodablesTests: XCTestCase {

    func testChatCompletionResponseIsDecodable() throws {
        let serializedBody = #"""
        {
          "choices": [
            {
              "finish_reason": "stop",
              "index": 0,
              "logprobs": null,
              "message": {
                "content": "pong",
                "reasoning": "We need answer single word pong. Need comply.",
                "reasoning_content": "We need answer single word pong. Need comply.",
                "role": "assistant"
              }
            }
          ],
          "created": 1794323037,
          "id": "chatcmpl-44872dd7-062d-9671-9d7d-d0748ac8e0ed",
          "model": "deepseek/deepseek-v4.1-flash",
          "object": "chat.completion",
          "usage": {
            "completion_tokens": 15,
            "completion_tokens_details": {
              "reasoning_tokens": 11,
              "text_tokens": 3
            },
            "prompt_tokens": 38,
            "prompt_tokens_details": {
              "cached_tokens": 0,
              "image_tokens": 0,
              "text_tokens": 38
            },
            "total_tokens": 53,
            "cost_usd": 1.62e-06
          }
        }
        """#
        let body = try OpenAIChatCompletionResponseBody.deserialize(from: serializedBody)
        XCTAssertEqual("deepseek/deepseek-v4.1-flash", body.model)
        XCTAssertEqual("pong", body.choices.first?.message.content)
        XCTAssertEqual("stop", body.choices.first?.finishReason)
        XCTAssertEqual(53, body.usage?.totalTokens)
    }

    func testStreamingContentChunkIsDecodable() {
        let line = #"""
        data: {"choices":[{"index":0,"delta":{"content":"1"},"finish_reason":null}],"created":1794323029,"id":"chatcmpl-Eihfx9VwR10rJslDja1RIMOpcuGB2","model":"openai/gpt-5.4-mini","object":"chat.completion.chunk","usage":null}
        """#
        let res = OpenAIChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual("1", res?.choices.first?.delta.content)
    }

    func testStreamingUsageChunkIsDecodable() {
        let line = #"""
        data: {"choices":[],"created":1794323029,"id":"chatcmpl-Eihfx9VwR10rJslDja1RIMOpcuGB2","model":"openai/gpt-5.4-mini","object":"chat.completion.chunk","usage":{"completion_tokens":12,"completion_tokens_details":{"reasoning_tokens":0,"audio_tokens":0,"accepted_prediction_tokens":0,"rejected_prediction_tokens":0},"prompt_tokens":16,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0},"total_tokens":28,"cost_usd":0.000006}}
        """#
        let res = OpenAIChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual(16, res?.usage?.promptTokens)
        XCTAssertEqual(12, res?.usage?.completionTokens)
        XCTAssertEqual(28, res?.usage?.totalTokens)
    }

    func testDirectServiceFactoryReturnsDirectService() {
        let service = AIProxy.uberllmDirectService(unprotectedAPIKey: "test-key")
        XCTAssertTrue(service is UberLLMDirectService)
    }
}
