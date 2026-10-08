//
//  AnthropicMessageRequestBody.swift
//
//
//  Created by Lou Zell on 7/25/24.
//

import Foundation

/// Message request body for posts to `/v1/messages`
///
/// Send a structured list of input messages with text and/or image content, and the model will generate the next message in the conversation.
///
/// The Messages API can be used for either single queries or stateless multi-turn conversations.
///
/// All docstrings in this file are from: https://platform.claude.com/docs/en/api/messages/create
nonisolated public struct AnthropicMessageRequestBody: Encodable, Sendable {

    // MARK: - Required Parameters

    /// The maximum number of tokens to generate before stopping.
    ///
    /// Note that our models may stop before reaching this maximum.
    /// This parameter only specifies the absolute maximum number of tokens to generate.
    ///
    /// Different models have different maximum values for this parameter.
    /// See models for details: https://docs.claude.com/en/docs/models-overview
    public let maxTokens: Int

    /// Input messages.
    ///
    /// Our models are trained to operate on alternating `user` and `assistant` conversational turns.
    /// When creating a new `Message`, you specify the prior conversational turns with the `messages` parameter,
    /// and the model then generates the next `Message` in the conversation.
    ///
    /// Consecutive `user` or `assistant` turns in your request will be combined into a single turn.
    ///
    /// Each input message must be an object with a `role` and `content`.
    /// You can specify a single `user`-role message, or you can include multiple `user` and `assistant` messages.
    ///
    /// If the final message uses the `assistant` role, the response content will continue immediately from the content in that message.
    /// This can be used to constrain part of the model's response.
    ///
    /// Example with a single user message:
    ///
    ///     [{"role": "user", "content": "Hello, Claude"}]
    ///
    /// Example with multiple conversational turns:
    ///
    ///     [
    ///       {"role": "user", "content": "Hello there."},
    ///       {"role": "assistant", "content": "Hi, I'm Claude. How can I help you?"},
    ///       {"role": "user", "content": "Can you explain LLMs in plain English?"},
    ///     ]
    ///
    /// Example with a partially-filled response from Claude:
    ///
    ///     [
    ///       {"role": "user", "content": "What's the Greek name for Sun? (A) Sol (B) Helios (C) Sun"},
    ///       {"role": "assistant", "content": "The best answer is ("},
    ///     ]
    ///
    /// Each input message `content` may be either a single `string` or an array of content blocks, where each block has a specific `type`.
    /// Using a `string` for `content` is shorthand for an array of one content block of type `"text"`.
    /// The following input messages are equivalent:
    ///
    ///         {"role": "user", "content": "Hello, Claude"}
    ///
    ///         {"role": "user", "content": [{"type": "text", "text": "Hello, Claude"}]}
    ///
    /// See input examples: https://docs.claude.com/en/api/messages-examples
    ///
    /// Note that if you want to include a system prompt, you can use the top-level `system` parameter —
    /// there is no `"system"` role for input messages in the Messages API.
    /// See https://docs.claude.com/en/docs/system-prompts
    ///
    /// There is a limit of 100,000 messages in a single request.
    public let messages: [AnthropicMessageParam]

    /// The model that will complete your prompt.
    ///
    /// For model strings and additional details about each model, see https://docs.anthropic.com/en/docs/about-claude/models#model-names
    public let model: String

    // MARK: - Optional Parameters

    /// An object describing metadata about the request.
    public let metadata: AnthropicRequestMetadata?

    /// Output configuration, currently the effort level (thinking depth and overall token use).
    ///
    /// Supported on Claude 4.6 and later. See https://docs.claude.com/en/docs/build-with-claude/effort
    public let outputConfig: AnthropicOutputConfig?

    /// Determines whether to use priority capacity (if available) or standard capacity for this request.
    ///
    /// Anthropic offers different levels of service for your API requests.
    /// For details, see: https://docs.claude.com/en/api/service-tiers
    public let serviceTier: AnthropicServiceTierParam?

    /// Custom text sequences that will cause the model to stop generating.
    ///
    /// Our models will normally stop when they have naturally completed their turn, which will
    /// result in a response `stop_reason` of `"end_turn"`.
    ///
    /// If you want the model to stop generating when it encounters custom strings of text, you can
    /// use the stop_sequences parameter. If the model encounters one of the custom sequences, the
    /// response stop_reason value will be "stop_sequence" and the response stop_sequence value
    /// will contain the matched stop sequence.
    public let stopSequences: [String]?

    /// Whether to incrementally stream the response using server-sent events.
    ///
    /// See https://docs.claude.com/en/api/messages-streaming
    public var stream: Bool?

    /// System prompt.
    ///
    /// A system prompt is a way of providing context and instructions to Claude, such as specifying
    /// a particular goal or role. See our guide to system prompts: https://docs.claude.com/en/docs/system-prompts
    public let system: AnthropicSystemPrompt?

    /// Amount of randomness injected into the response.
    ///
    /// Defaults to `1.0`. Ranges from `0.0` to `1.0`. Use `temperature` closer to `0.0` for
    /// analytical / multiple choice, and closer to `1.0` for creative and generative tasks.
    ///
    /// Note that even with `temperature` of `0.0`, the results will not be fully deterministic.
    public let temperature: Double?

    /// Configuration for Claude's extended thinking.
    ///
    /// When thinking is on, responses include `thinking` content blocks before the final answer,
    /// and the thinking tokens count towards your `max_tokens` limit. Claude 4.6 and later run
    /// adaptive thinking when this is omitted; see `AnthropicThinkingConfigParam` for which cases
    /// each model generation accepts.
    public let thinking: AnthropicThinkingConfigParam?

    /// How the model should use the provided tools.
    ///
    /// The model can use a specific tool, any available tool, decide by itself, or not use tools at all.
    /// More information here: https://docs.anthropic.com/en/docs/build-with-claude/tool-use
    public let toolChoice: AnthropicToolChoice?

    /// Definitions of tools that the model may use.
    ///
    /// If you include `tools` in your API request, the model may return `tool_use` content blocks
    /// that represent the model's use of those tools. You can then run those tools using the tool
    /// input generated by the model and then optionally return results back to the model using
    /// `tool_result` content blocks.
    ///
    /// Each tool definition includes:
    ///
    /// - name: Name of the tool.
    /// - description: Optional, but strongly-recommended description of the tool.
    /// - input_schema: JSON schema for the tool input shape that the model will produce in tool_use output content blocks.
    ///
    /// For example, if you defined tools as:
    ///
    ///     [
    ///       {
    ///         "name": "get_stock_price",
    ///         "description": "Get the current stock price for a given ticker symbol.",
    ///         "input_schema": {
    ///           "type": "object",
    ///           "properties": {
    ///             "ticker": {
    ///               "type": "string",
    ///               "description": "The stock ticker symbol, e.g. AAPL for Apple Inc."
    ///             }
    ///           },
    ///           "required": ["ticker"]
    ///         }
    ///       }
    ///     ]
    ///
    /// And then asked the model "What's the S&P 500 at today?", the model might produce tool_use
    /// content blocks in the response like this:
    ///
    ///     [
    ///       {
    ///         "type": "tool_use",
    ///         "id": "toolu_01D7FLrfh4GYq7yT1ULFeyMV",
    ///         "name": "get_stock_price",
    ///         "input": { "ticker": "^GSPC" }
    ///       }
    ///     ]
    ///
    /// You might then run your get_stock_price tool with {"ticker": "^GSPC"} as an input, and
    /// return the following back to the model in a subsequent user message:
    ///
    ///     [
    ///       {
    ///         "type": "tool_result",
    ///         "tool_use_id": "toolu_01D7FLrfh4GYq7yT1ULFeyMV",
    ///         "content": "259.75 USD"
    ///       }
    ///     ]
    ///
    /// Tools can be used for workflows that include running client-side tools and functions, or
    /// more generally whenever you want the model to produce a particular JSON structure of
    /// output.
    ///
    /// See this guide for more details: https://docs.anthropic.com/en/docs/tool-use
    public let tools: [AnthropicToolUnion]?

    /// Only sample from the top K options for each subsequent token.
    ///
    /// Used to remove "long tail" low probability responses.
    /// Learn more technical details here: https://towardsdatascience.com/how-to-sample-from-language-models-682bceb97277
    ///
    /// Recommended for advanced use cases only. You usually only need to use `temperature`.
    public let topK: Int?

    /// Use nucleus sampling.
    ///
    /// In nucleus sampling, we compute the cumulative distribution over all the options for each
    /// subsequent token in decreasing probability order and cut it off once it reaches a
    /// particular probability specified by `top_p`.
    ///
    /// You should either alter `temperature` or `top_p`, but not both.
    ///
    /// Recommended for advanced use cases only. You usually only need to use `temperature`.
    public let topP: Double?

    private enum CodingKeys: String, CodingKey {
        // Required
        case maxTokens = "max_tokens"
        case messages
        case model

        // Optional
        case metadata
        case outputConfig = "output_config"
        case serviceTier = "service_tier"
        case stopSequences = "stop_sequences"
        case stream
        case system
        case temperature
        case thinking
        case toolChoice = "tool_choice"
        case tools
        case topK = "top_k"
        case topP = "top_p"
    }

    // This memberwise initializer is autogenerated.
    // To regenerate, use `cmd-shift-a` > Generate Memberwise Initializer
    // To format, place the cursor in the initializer's parameter list and use `ctrl-m`
    public init(
        maxTokens: Int,
        messages: [AnthropicMessageParam],
        model: String,
        metadata: AnthropicRequestMetadata? = nil,
        outputConfig: AnthropicOutputConfig? = nil,
        serviceTier: AnthropicServiceTierParam? = nil,
        stopSequences: [String]? = nil,
        stream: Bool? = nil,
        system: AnthropicSystemPrompt? = nil,
        temperature: Double? = nil,
        thinking: AnthropicThinkingConfigParam? = nil,
        toolChoice: AnthropicToolChoice? = nil,
        tools: [AnthropicToolUnion]? = nil,
        topK: Int? = nil,
        topP: Double? = nil
    ) {
        self.maxTokens = maxTokens
        self.messages = messages
        self.model = model
        self.metadata = metadata
        self.outputConfig = outputConfig
        self.serviceTier = serviceTier
        self.stopSequences = stopSequences
        self.stream = stream
        self.system = system
        self.temperature = temperature
        self.thinking = thinking
        self.toolChoice = toolChoice
        self.tools = tools
        self.topK = topK
        self.topP = topP
    }
}
