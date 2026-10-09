//
//  OpenRouterToolCallResponseBodyTests.swift
//  AIProxy
//
//  Created by Lou Zell on 4/16/25.
//

import Foundation
import XCTest
@testable import AIProxy

final class OpenRouterToolCallResponseBodyTests: XCTestCase {

    func testResponseWithToolUseIsDecodable() throws {
        let sampleResponse = #"""
        {
          "id": "gen-1744845790-VDqUk3HsqsMOdoNex7FH",
          "provider": "DeepInfra",
          "model": "meta-llama/llama-3.3-70b-instruct",
          "object": "chat.completion",
          "created": 1744845790,
          "choices": [
            {
              "logprobs": null,
              "finish_reason": "stop",
              "native_finish_reason": "stop",
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "",
                "refusal": null,
                "reasoning": null,
                "tool_calls": [
                  {
                    "index": 0,
                    "id": "call_mWR7JQZV1ttdehPlT2y0tP2k",
                    "function": {
                      "arguments": "{\"location\": \"San Francisco, USA\"}",
                      "name": "get_weather"
                    },
                    "type": "function"
                  }
                ]
              }
            }
          ],
          "usage": {
            "prompt_tokens": 243,
            "completion_tokens": 16,
            "total_tokens": 259
          }
        }
        """#
        let res = try OpenRouterChatCompletionResponseBody.deserialize(from: sampleResponse)
        let functionToCall = res.choices.first?.message.toolCalls?.first?.function
        XCTAssertEqual("get_weather", functionToCall?.name)
        XCTAssertEqual(
            "San Francisco, USA",
            functionToCall?.arguments?["location"] as? String
        )
    }

    func testStreamingResponseWithToolUseIsDecodable() throws {
        let line = #"data: {"id":"snip","provider":"OpenAI","model":"openai/gpt-4.1","object":"chat.completion.chunk","created":1753924334,"choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"call_123","function":{"arguments":" USA"},"type":"function"}]},"finish_reason":null,"native_finish_reason":null,"logprobs":null}],"system_fingerprint":"snip"}"#
        let chunk = OpenRouterChatCompletionChunk.deserialize(fromLine: line)
        XCTAssertEqual("call_123", chunk?.choices.first?.delta.toolCalls?.first?.id)
        XCTAssertEqual(
            " USA",
            chunk?.choices.first?.delta.toolCalls?.first?.function?.arguments
        )
    }
}
