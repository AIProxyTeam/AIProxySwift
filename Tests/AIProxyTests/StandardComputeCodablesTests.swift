//
//  StandardComputeCodablesTests.swift
//  AIProxy
//
//  Created by Henrik Bakke Dukefoss on 11/9/26.
//

import XCTest
@testable import AIProxy

final class StandardComputeCodablesTests: XCTestCase {

    func testChatCompletionResponseIsDecodable() throws {
        let serializedBody = #"""
        {
          "id": "chatcmpl-8f2c1d0e4b6a4f7e9c3a2b1d0e9f8a7b",
          "object": "chat.completion",
          "created": 1794211200,
          "model": "deepseek/deepseek-v4-flash",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "Hello! How can I help you today?"
              },
              "finish_reason": "stop",
              "logprobs": null
            }
          ],
          "usage": {
            "prompt_tokens": 18,
            "completion_tokens": 10,
            "total_tokens": 28
          }
        }
        """#
        let body = try OpenAIChatCompletionResponseBody.deserialize(from: serializedBody)
        XCTAssertEqual("deepseek/deepseek-v4-flash", body.model)
        XCTAssertEqual("Hello! How can I help you today?", body.choices.first?.message.content)
        XCTAssertEqual("stop", body.choices.first?.finishReason)
        XCTAssertEqual(28, body.usage?.totalTokens)
    }

    func testStreamingContentChunkIsDecodable() {
        let line = #"""
        data: {"id":"chatcmpl-3a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d","object":"chat.completion.chunk","created":1794211201,"model":"deepseek/deepseek-v4-flash","choices":[{"index":0,"delta":{"role":"assistant","content":"Hi"},"logprobs":null,"finish_reason":null}],"usage":null}
        """#
        let res = OpenAIChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual("Hi", res?.choices.first?.delta.content)
    }

    func testStreamingUsageChunkIsDecodable() {
        let line = #"""
        data: {"id":"chatcmpl-3a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d","object":"chat.completion.chunk","created":1794211202,"model":"deepseek/deepseek-v4-flash","choices":[],"usage":{"prompt_tokens":18,"completion_tokens":10,"total_tokens":28}}
        """#
        let res = OpenAIChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual(18, res?.usage?.promptTokens)
        XCTAssertEqual(10, res?.usage?.completionTokens)
        XCTAssertEqual(28, res?.usage?.totalTokens)
    }

    func testDirectServiceFactoryReturnsDirectService() {
        let service = AIProxy.standardComputeDirectService(unprotectedAPIKey: "test-key")
        XCTAssertTrue(service is StandardComputeDirectService)
    }

    func testProxiedServiceFactoryReturnsProxiedService() {
        let service = AIProxy.standardComputeService(
            partialKey: "test-partial-key",
            serviceURL: "https://api.aiproxy.com/test/service"
        )
        XCTAssertTrue(service is StandardComputeProxiedService)
    }
}
