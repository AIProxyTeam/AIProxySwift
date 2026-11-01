//
//  RuncrateCodablesTests.swift
//  AIProxy
//
//  Created by heydryft on 11/1/26.
//

import XCTest
@testable import AIProxy

final class RuncrateCodablesTests: XCTestCase {

    func testChatCompletionResponseIsDecodable() throws {
        let serializedBody = #"""
        {
          "id": "chatcmpl-req_e5f84f5f9813491898d6afe25eb64884",
          "object": "chat.completion",
          "created": 1793530031,
          "model": "openai/gpt-oss-120b",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "Hi there! How can I help you today?",
                "reasoning_content": "Just respond friendly."
              },
              "finish_reason": "stop",
              "logprobs": null
            }
          ],
          "usage": {
            "prompt_tokens": 56,
            "completion_tokens": 26,
            "total_tokens": 82,
            "cost": 0.0000068166
          },
          "system_fingerprint": null
        }
        """#
        let body = try OpenAIChatCompletionResponseBody.deserialize(from: serializedBody)
        XCTAssertEqual("openai/gpt-oss-120b", body.model)
        XCTAssertEqual("Hi there! How can I help you today?", body.choices.first?.message.content)
        XCTAssertEqual("stop", body.choices.first?.finishReason)
        XCTAssertEqual(82, body.usage?.totalTokens)
    }

    func testStreamingContentChunkIsDecodable() {
        let line = #"""
        data: {"id":"chatcmpl-req_b8cbe4b0d6c741a58cd9558f363aef3e","object":"chat.completion.chunk","created":1793530068,"model":"openai/gpt-oss-120b","choices":[{"index":0,"delta":{"role":"assistant","content":"Hi","reasoning_content":null},"logprobs":null,"finish_reason":null}],"usage":null,"system_fingerprint":null}
        """#
        let res = OpenAIChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual("Hi", res?.choices.first?.delta.content)
    }

    func testStreamingUsageChunkIsDecodable() {
        let line = #"""
        data: {"id":"chatcmpl-req_f103e5c17a5344a6bc18f906d80426cf","object":"chat.completion.chunk","created":1793530109,"model":"openai/gpt-oss-120b","choices":[],"usage":{"prompt_tokens":56,"completion_tokens":26,"total_tokens":82,"cost":0.0000068166},"system_fingerprint":null}
        """#
        let res = OpenAIChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual(56, res?.usage?.promptTokens)
        XCTAssertEqual(26, res?.usage?.completionTokens)
        XCTAssertEqual(82, res?.usage?.totalTokens)
    }

    func testEmbeddingResponseIsDecodable() throws {
        let serializedBody = #"""
        {
          "object": "list",
          "data": [
            {
              "object": "embedding",
              "index": 0,
              "embedding": [-0.05288286879658699, -0.06336196511983871, -0.03704237937927246]
            }
          ],
          "model": "Qwen/Qwen3-Embedding-0.6B",
          "usage": {
            "prompt_tokens": 2,
            "total_tokens": 2
          }
        }
        """#
        let body = try OpenAIEmbeddingResponseBody.deserialize(from: serializedBody)
        XCTAssertEqual("Qwen/Qwen3-Embedding-0.6B", body.model)
        XCTAssertEqual(3, body.embeddings.first?.vector.count)
        XCTAssertEqual(0, body.embeddings.first?.index)
    }

    func testDirectServiceFactoryReturnsDirectService() {
        let service = AIProxy.runcrateDirectService(unprotectedAPIKey: "test-key")
        XCTAssertTrue(service is RuncrateDirectService)
    }
}
