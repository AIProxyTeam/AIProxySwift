//
//  OpenRouterChatCompletionRequestTests.swift
//  AIProxy
//

import XCTest
@testable import AIProxy

final class OpenRouterChatCompletionRequestTests: XCTestCase {

    func testToolCallConversationIsEncodable() throws {
        let request = OpenRouterChatCompletionRequestBody(
            messages: [
                .user(content: .text("What is the weather?")),
                .assistant(
                    toolCalls: [
                        .init(
                            id: "call_123",
                            function: .init(
                                name: "get_weather",
                                arguments: #"{"location":"Denver"}"#
                            )
                        )
                    ]
                ),
                .tool(
                    content: #"{"temperature":72}"#,
                    toolCallID: "call_123"
                )
            ]
        )

        XCTAssertEqual(
            #"""
            {
              "messages" : [
                {
                  "content" : "What is the weather?",
                  "role" : "user"
                },
                {
                  "content" : null,
                  "role" : "assistant",
                  "tool_calls" : [
                    {
                      "function" : {
                        "arguments" : "{\"location\":\"Denver\"}",
                        "name" : "get_weather"
                      },
                      "id" : "call_123",
                      "type" : "function"
                    }
                  ]
                },
                {
                  "content" : "{\"temperature\":72}",
                  "role" : "tool",
                  "tool_call_id" : "call_123"
                }
              ]
            }
            """#,
            try request.serialize(pretty: true)
        )
    }
}
