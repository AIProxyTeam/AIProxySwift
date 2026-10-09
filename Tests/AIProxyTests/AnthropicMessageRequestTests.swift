//
//  File.swift
//
//
//  Created by Lou Zell on 7/28/24.
//

import Foundation

import XCTest
import Foundation
@testable import AIProxy


final class AnthropicMessageRequestTests: XCTestCase {

    func testRequestIsEncodable() throws {
        let request = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: [
                AnthropicMessageParam(content: [.textBlock(AnthropicTextBlockParam(text: "hello world"))], role: .user)
            ],
            model: "claude-3-5-sonnet-20240620"
        )
        XCTAssertEqual(
            #"{"max_tokens":1024,"messages":[{"content":[{"text":"hello world","type":"text"}],"role":"user"}],"model":"claude-3-5-sonnet-20240620"}"#
            ,
            try request.serialize()
        )
    }

    func testRequestWithAdaptiveThinkingAndEffortIsEncodable() throws {
        let request = AnthropicMessageRequestBody(
            maxTokens: 16000,
            messages: [
                AnthropicMessageParam(content: [.textBlock(AnthropicTextBlockParam(text: "hello world"))], role: .user)
            ],
            model: "claude-sonnet-5-5",
            outputConfig: AnthropicOutputConfig(effort: .medium),
            thinking: .adaptive
        )
        XCTAssertEqual(
            #"{"max_tokens":16000,"messages":[{"content":[{"text":"hello world","type":"text"}],"role":"user"}],"model":"claude-sonnet-5-5","output_config":{"effort":"medium"},"thinking":{"type":"adaptive"}}"#
            ,
            try request.serialize()
        )
    }

    func testRequestWithBetweenToolsThinkingIsEncodable() throws {
        let request = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: [
                AnthropicMessageParam(content: [.textBlock(AnthropicTextBlockParam(text: "hello world"))], role: .user)
            ],
            model: "claude-sonnet-5-5",
            outputConfig: AnthropicOutputConfig(effort: .low),
            thinking: .betweenTools
        )
        XCTAssertEqual(
            #"{"max_tokens":1024,"messages":[{"content":[{"text":"hello world","type":"text"}],"role":"user"}],"model":"claude-sonnet-5-5","output_config":{"effort":"low"},"thinking":{"type":"between_tools"}}"#
            ,
            try request.serialize()
        )
    }

    func testEmptyOutputConfigEncodesAsEmptyObject() throws {
        let request = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: [
                AnthropicMessageParam(content: [.textBlock(AnthropicTextBlockParam(text: "hi"))], role: .user)
            ],
            model: "claude-sonnet-5-5",
            outputConfig: AnthropicOutputConfig()
        )
        XCTAssertEqual(
            #"{"max_tokens":1024,"messages":[{"content":[{"text":"hi","type":"text"}],"role":"user"}],"model":"claude-sonnet-5-5","output_config":{}}"#
            ,
            try request.serialize()
        )
    }

    func testRequestWithToolUseIsEncodable() throws {
        let request = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: [
                AnthropicMessageParam(
                    content: [.textBlock(AnthropicTextBlockParam(text: "What's the temp in San Francisco?"))],
                    role: .user
                )
            ],
            model: "claude-3-5-sonnet-20240620",
            tools: [
                .customTool(AnthropicTool(
                    description: "Call this function when the user wants the weather",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "location": [
                                "type": "string",
                                "description": "The city and state, e.g. San Francisco, CA"
                            ],
                            "unit": [
                              "type": "string",
                              "enum": ["celsius", "fahrenheit"],
                              "description": "The unit of temperature. Default to fahrenheit",
                              "default": "fahrenheit"
                            ]
                        ],
                        "required": ["location", "unit"]
                    ],
                    name: "get_weather"
                ))
            ]
        )
        XCTAssertEqual(
            #"{"max_tokens":1024,"messages":[{"content":[{"text":"What's the temp in San Francisco?","type":"text"}],"role":"user"}],"model":"claude-3-5-sonnet-20240620","tools":[{"description":"Call this function when the user wants the weather","input_schema":{"properties":{"location":{"description":"The city and state, e.g. San Francisco, CA","type":"string"},"unit":{"default":"fahrenheit","description":"The unit of temperature. Default to fahrenheit","enum":["celsius","fahrenheit"],"type":"string"}},"required":["location","unit"],"type":"object"},"name":"get_weather","type":"custom"}]}"#
            ,
            try request.serialize()
        )
    }

    func testRequestWithImageIsEncodable() throws {
        let request = AnthropicMessageRequestBody(
            maxTokens: 1024,
            messages: [
                AnthropicMessageParam(content: [.imageBlock(AnthropicImageBlockParam(
                    source: .base64(data: "encoded-image", mediaType: .jpeg)
                ))], role: .user)
            ],
            model: "claude-3-5-sonnet-20240620"
        )
        XCTAssertEqual(
            #"{"max_tokens":1024,"messages":[{"content":[{"source":{"data":"encoded-image","media_type":"image\/jpeg","type":"base64"},"type":"image"}],"role":"user"}],"model":"claude-3-5-sonnet-20240620"}"#
            ,
            try request.serialize()
        )
    }
}
