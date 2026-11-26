//
//  OpenAIRealtimeResponseCreate.swift
//
//
//  Created by Lou Zell on 10/14/24.
//

import Foundation

/// https://platform.openai.com/docs/api-reference/realtime-client-events/response
nonisolated public struct OpenAIRealtimeResponseCreate: Encodable {
    public let type = "response.create"
    public let eventID: String?
    public let response: Response?

    private enum CodingKeys: String, CodingKey {
        case type
        case eventID = "event_id"
        case response
    }

    public init(eventID: String? = nil, response: Response? = nil) {
        self.eventID = eventID
        self.response = response
    }
}

// MARK: -
extension OpenAIRealtimeResponseCreate {
    nonisolated public struct Response: Encodable {
        public let conversation: String?
        public let instructions: String?
        /// Encoded as `output_modalities` on the wire.
        public let outputModalities: [OpenAIRealtimeSessionConfiguration.Modality]?
        @available(*, deprecated, renamed: "outputModalities")
        public var modalities: [OpenAIRealtimeSessionConfiguration.Modality]? { outputModalities }
        public let toolChoice: OpenAIRealtimeSessionConfiguration.ToolChoice?
        public let tools: [Tool]?
        /// Optional reasoning settings for models that support Realtime Reasoning.
        public let reasoning: OpenAIRealtimeReasoning?
        /// Whether the model may call multiple tools in parallel. Omitted when nil.
        public let parallelToolCalls: Bool?

        private enum CodingKeys: String, CodingKey {
            case conversation
            case instructions
            case outputModalities = "output_modalities"
            case toolChoice = "tool_choice"
            case tools
            case reasoning
            case parallelToolCalls = "parallel_tool_calls"
        }

        public init(
            conversation: String? = nil,
            instructions: String? = nil,
            outputModalities: [OpenAIRealtimeSessionConfiguration.Modality]? = nil,
            tools: [Tool]? = nil,
            toolChoice: OpenAIRealtimeSessionConfiguration.ToolChoice? = nil,
            reasoning: OpenAIRealtimeReasoning? = nil,
            parallelToolCalls: Bool? = nil
        ) {
            self.conversation = conversation
            self.instructions = instructions
            self.outputModalities = outputModalities
            self.tools = tools
            self.toolChoice = toolChoice
            self.reasoning = reasoning
            self.parallelToolCalls = parallelToolCalls
        }

        /// Deprecated initializer preserved for source compatibility.
        @available(*, deprecated, message: "Use outputModalities (JSON key output_modalities).")
        @_disfavoredOverload
        public init(
            conversation: String? = nil,
            instructions: String? = nil,
            modalities: [OpenAIRealtimeSessionConfiguration.Modality]? = nil,
            tools: [Tool]? = nil,
            toolChoice: OpenAIRealtimeSessionConfiguration.ToolChoice? = nil,
            reasoning: OpenAIRealtimeReasoning? = nil,
            parallelToolCalls: Bool? = nil
        ) {
            self.init(
                conversation: conversation,
                instructions: instructions,
                outputModalities: modalities,
                tools: tools,
                toolChoice: toolChoice,
                reasoning: reasoning,
                parallelToolCalls: parallelToolCalls
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(conversation, forKey: .conversation)
            try container.encodeIfPresent(instructions, forKey: .instructions)
            try container.encodeIfPresent(outputModalities, forKey: .outputModalities)
            try container.encodeIfPresent(tools, forKey: .tools)
            try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
            try container.encodeIfPresent(reasoning, forKey: .reasoning)
            try container.encodeIfPresent(parallelToolCalls, forKey: .parallelToolCalls)
        }
    }
}

// MARK: -
extension OpenAIRealtimeResponseCreate.Response {
    nonisolated public enum Tool: Encodable {
        case function(OpenAIRealtimeSessionConfiguration.FunctionTool)
        case mcp(OpenAIRealtimeSessionConfiguration.MCPTool)
        case webSearch(OpenAICreateResponseRequestBody.WebSearchTool)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .function(let functionTool):
                try functionTool.encode(to: encoder)
            case .mcp(let mcpTool):
                try mcpTool.encode(to: encoder)
            case .webSearch(let webSearchTool):
                try webSearchTool.encode(to: encoder)
            }
        }
    }
}
