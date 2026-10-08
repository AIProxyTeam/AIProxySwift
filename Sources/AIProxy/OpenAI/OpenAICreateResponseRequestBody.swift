//
//  OpenAICreateResponseRequestBody.swift
//  AIProxy
//
//  Created by Lou Zell on 3/12/25.
//

import Foundation

/// OpenAI's most advanced interface for generating model responses.
/// Supports text and image inputs, and text outputs.
/// Create stateful interactions with the model, using the output of previous responses as input.
/// Extend the model's capabilities with built-in tools for file search, web search, computer use, and more.
/// Allow the model access to external systems and data using function calling.
/// https://developers.openai.com/api/reference/resources/responses/methods/create
/// Implementor's note: See ResponseCreateParamsBase in `src/openai/types/responses/response_create_params.py`
nonisolated public struct OpenAICreateResponseRequestBody: Encodable, Sendable {

    /// Whether to run generation in the background. Omitted unless explicitly supplied.
    public let background: Bool?

    /// Specify additional output data to include in the model response.
    public let include: [OpenAIInclude]?

    /// Text, image, or file inputs to the model, used to generate a response.
    public let input: OpenAIResponse.Input?

    /// Inserts a system (or developer) message as the first item in the model's context.
    /// When using along with `previousResponseId`, the instructions from a previous response
    /// will not be carried over to the next response. This makes it simple to swap out system
    /// (or developer) messages in new responses.
    public let instructions: String?

    /// An upper bound for the number of tokens that can be generated for a response,
    /// including visible output tokens and reasoning tokens: https://developers.openai.com/docs/guides/reasoning
    public let maxOutputTokens: Int?

    /// Elements of the JSON `context_management` array on the create-response request.
    public let contextManagement: [ContextManagementItem]?

    /// Model ID used to generate the response, like gpt-4o or o1.
    /// OpenAI offers a wide range of models with different capabilities, performance characteristics, and price points.
    /// Refer to the model guide to browse and compare available models: https://platform.openai.com/docs/models
    public let model: String?

    /// Whether to allow the model to run tool calls in parallel.
    /// Defaults to true if not specified.
    public let parallelToolCalls: Bool?

    /// The unique ID of the previous response to the model. Use this to create multi-turn conversations.
    /// Learn more: https://platform.openai.com/docs/guides/conversation-state
    public let previousResponseId: String?

    /// Reference to a prompt template and its variables
    /// Learn more: https://platform.openai.com/docs/guides/text?api-mode=responses#reusable-prompts
    public let prompt: Prompt?

    /// o-series models only
    /// Configuration options for reasoning models.
    public let reasoning: Reasoning?

    /// A stable identifier used to help detect users of your application that may be violating OpenAI's usage policies.
    /// The IDs should be a string that uniquely identifies each user.
    /// We recommend hashing their username or email address, in order to avoid sending us any identifying information.
    public let safetyIdentifier: String?

    /// Whether to store the generated model response for later retrieval via API.
    /// Defaults to true.
    public let store: Bool?

    /// If set, partial response deltas will be sent as server-sent events.
    /// Set this to true when using the streaming response method.
    public var stream: Bool?

    /// What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random,
    /// while lower values like 0.2 will make it more focused and deterministic.
    public let temperature: Double?

    /// Configuration options for a text response from the model. Can be plain text or structured JSON data.
    public let text: OpenAIResponse.TextConfiguration?

    /// How the model should select which tool (or tools) to use when generating a response.
    public let toolChoice: ToolChoice?

    /// An array of tools the model may call while generating a response.
    /// You can specify which tool to use by setting the tool_choice parameter.
    /// The two categories of tools you can provide the model are:
    /// - Built-in tools: Tools that are provided by OpenAI that extend the model's capabilities,
    ///   like web search or file search.
    /// - Function calls (custom tools): Functions that are defined by you,
    ///   enabling the model to call your own code.
    public let tools: [Tool]?

    /// An alternative to sampling with temperature, called nucleus sampling, where the model considers the results of the tokens with `topP` probability mass.
    /// So 0.1 means only the tokens comprising the top 10% probability mass are considered.
    /// We generally recommend altering this or temperature but not both.
    public let topP: Double?

    /// The truncation strategy to use for the model response.
    public let truncation: Truncation?

    /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    public let user: String?

    private enum CodingKeys: String, CodingKey {
        case background
        case include
        case input
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case contextManagement = "context_management"
        case model
        case tools
        case toolChoice = "tool_choice"
        case reasoning
        case safetyIdentifier = "safety_identifier"
        case store
        case parallelToolCalls = "parallel_tool_calls"
        case previousResponseId = "previous_response_id"
        case prompt
        case truncation
        case stream
        case temperature
        case topP = "top_p"
        case user
        case text
    }

    // This memberwise initializer is autogenerated.
    // To regenerate, use `cmd-shift-a` > Generate Memberwise Initializer
    // To format, place the cursor in the initializer's parameter list and use `ctrl-m`
    public init(
        background: Bool? = nil,
        include: [OpenAIInclude]? = nil,
        input: OpenAIResponse.Input? = nil,
        instructions: String? = nil,
        maxOutputTokens: Int? = nil,
        contextManagement: [OpenAICreateResponseRequestBody.ContextManagementItem]? = nil,
        model: String? = nil,
        parallelToolCalls: Bool? = nil,
        previousResponseId: String? = nil,
        prompt: OpenAICreateResponseRequestBody.Prompt? = nil,
        reasoning: OpenAICreateResponseRequestBody.Reasoning? = nil,
        safetyIdentifier: String? = nil,
        store: Bool? = nil,
        stream: Bool? = nil,
        temperature: Double? = nil,
        text: OpenAIResponse.TextConfiguration? = nil,
        toolChoice: OpenAICreateResponseRequestBody.ToolChoice? = nil,
        tools: [OpenAICreateResponseRequestBody.Tool]? = nil,
        topP: Double? = nil,
        truncation: OpenAICreateResponseRequestBody.Truncation? = nil,
        user: String? = nil
    ) {
        self.background = background
        self.include = include
        self.input = input
        self.instructions = instructions
        self.maxOutputTokens = maxOutputTokens
        self.contextManagement = contextManagement
        self.model = model
        self.parallelToolCalls = parallelToolCalls
        self.previousResponseId = previousResponseId
        self.prompt = prompt
        self.reasoning = reasoning
        self.safetyIdentifier = safetyIdentifier
        self.store = store
        self.stream = stream
        self.temperature = temperature
        self.text = text
        self.toolChoice = toolChoice
        self.tools = tools
        self.topP = topP
        self.truncation = truncation
        self.user = user
    }

    // For naming consistency with sdkVersion <= 0.120.0
    public typealias TextSettings = OpenAIResponse.TextConfiguration
}

extension OpenAICreateResponseRequestBody {

    /// One object in the JSON `context_management` array (`type`, `compact_threshold`, …).
    nonisolated public struct ContextManagementItem: Encodable, Sendable {
        /// The context management entry type. Currently only `compaction` is supported.
        public let type: EntryType

        /// Token threshold at which compaction should be triggered for this entry.
        public let compactThreshold: Int?

        private enum CodingKeys: String, CodingKey {
            case type
            case compactThreshold = "compact_threshold"
        }

        public init(
            type: EntryType = .compaction,
            compactThreshold: Int? = nil
        ) {
            self.type = type
            self.compactThreshold = compactThreshold
        }

        nonisolated public enum EntryType: String, Encodable, Sendable {
            case compaction
        }
    }

    /// Legacy name for one element of the JSON `context_management` array.
    @available(*, deprecated, renamed: "ContextManagementItem")
    public typealias ContextManagement = ContextManagementItem

    /// The truncation strategy to use for the model response.
    nonisolated public enum Truncation: String, Encodable, Sendable {
        /// If the input to this response exceeds the model's context window size, the model will truncate the response to fit the context window by dropping items from the beginning of the conversation.
        case auto

        /// If the input size will exceed the context window size for a model, the request will fail with a 400 error.
        case disabled
    }

    nonisolated public struct Prompt: Encodable, Sendable {
        /// The unique identifier of the prompt template to use.
        public let id: String

        /// Optional map of values to substitute in for variables in your prompt. The substitution values can either be strings, or other Response input types like images or files.
        public let variables: [String: Variable]?

        /// Optional version of the prompt template.
        public let version: String?

        public init(
            id: String,
            variables: [String : OpenAICreateResponseRequestBody.Variable]? = nil,
            version: String? = nil
        ) {
            self.id = id
            self.variables = variables
            self.version = version
        }
    }

    nonisolated public enum Variable: Encodable, Sendable {
        case text(String)

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let str):
                try container.encode(str)
            }
        }
    }
}

// MARK: - Tool Types
extension OpenAICreateResponseRequestBody {
    /// A tool specification that models can use in responses.
    /// See https://platform.openai.com/docs/guides/tools
    nonisolated public enum Tool: Codable, Sendable {

        /// Build a computer-using agent that can perform tasks on your behalf.
        /// https://platform.openai.com/docs/guides/tools-computer-use
        case computerUse(ComputerUseTool)

        /// Allow models to search your files for relevant information before generating a response.
        /// https://platform.openai.com/docs/guides/tools-file-search
        case fileSearch(FileSearchTool)

        /// Enable models to fetch data and take actions.
        /// https://platform.openai.com/docs/guides/function-calling?api-mode=responses
        case function(FunctionTool)

        /// Allow models to search the web for the latest information before generating a response.
        /// https://platform.openai.com/docs/guides/tools-web-search?api-mode=responses
        case webSearch(WebSearchTool)

        /// Allow models to search the web for the latest information before generating a response (preview version).
        /// https://platform.openai.com/docs/guides/tools-web-search?api-mode=respons
        /// Not including the deprecated message as it causes a compiler warning in our own decoder conformance on OpenAIResponseTool.
        // @available(*, deprecated, message: "Use webSearch if using a modern GPT model. webSearchPreview will be removed in a future version.")
        case webSearchPreview(WebSearchPreviewTool)

        private enum CodingKeys: String, CodingKey {
            case description
            case displayHeight = "display_height"
            case displayWidth = "display_width"
            case environment
            case filters
            case maxNumResults = "max_num_results"
            case name
            case parameters
            case rankingOptions = "ranking_options"
            case searchContextSize = "search_context_size"
            case strict
            case type
            case userLocation = "user_location"
            case vectorStoreIDs = "vector_store_ids"
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .fileSearch(let tool):
                try container.encode("file_search", forKey: .type)
                try container.encode(tool.vectorStoreIDs, forKey: .vectorStoreIDs)
                try container.encodeIfPresent(tool.filters, forKey: .filters)
                try container.encodeIfPresent(tool.maxNumResults, forKey: .maxNumResults)
                try container.encodeIfPresent(tool.rankingOptions, forKey: .rankingOptions)

            case .webSearch(let tool):
                try container.encode("web_search", forKey: .type)
                try container.encodeIfPresent(tool.searchContextSize, forKey: .searchContextSize)
                try container.encodeIfPresent(tool.userLocation, forKey: .userLocation)

            case .webSearchPreview(let tool):
                try container.encode("web_search_preview", forKey: .type)
                try container.encodeIfPresent(tool.searchContextSize, forKey: .searchContextSize)
                try container.encodeIfPresent(tool.userLocation, forKey: .userLocation)

            case .computerUse(let tool):
                try container.encode("computer_use_preview", forKey: .type)
                try container.encode(tool.displayWidth, forKey: .displayWidth)
                try container.encode(tool.displayHeight, forKey: .displayHeight)
                try container.encode(tool.environment, forKey: .environment)

            case .function(let tool):
                try container.encode("function", forKey: .type)
                try container.encode(tool.name, forKey: .name)
                try container.encode(tool.parameters, forKey: .parameters)
                try container.encode(tool.strict, forKey: .strict)
                try container.encodeIfPresent(tool.description, forKey: .description)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "file_search":
                let vectorStoreIDs = try container.decode([String].self, forKey: .vectorStoreIDs)
                let filters = try container.decodeIfPresent(FileSearchFilter.self, forKey: .filters)
                let maxNumResults = try container.decodeIfPresent(Int.self, forKey: .maxNumResults)
                let rankingOptions = try container.decodeIfPresent(FileSearchTool.RankingOptions.self, forKey: .rankingOptions)
                self = .fileSearch(FileSearchTool(vectorStoreIDs: vectorStoreIDs, filters: filters, maxNumResults: maxNumResults, rankingOptions: rankingOptions))

            case "web_search":
                let searchContextSize = try container.decodeIfPresent(WebSearchTool.SearchContextSize.self, forKey: .searchContextSize)
                let userLocation = try container.decodeIfPresent(WebSearchTool.UserLocation.self, forKey: .userLocation)
                self = .webSearch(WebSearchTool(searchContextSize: searchContextSize, userLocation: userLocation))

            case "web_search_preview":
                let searchContextSize = try container.decodeIfPresent(WebSearchTool.SearchContextSize.self, forKey: .searchContextSize)
                let userLocation = try container.decodeIfPresent(WebSearchTool.UserLocation.self, forKey: .userLocation)
                self = .webSearchPreview(WebSearchTool(searchContextSize: searchContextSize, userLocation: userLocation))

            case "computer_use_preview":
                let displayWidth = try container.decode(Int.self, forKey: .displayWidth)
                let displayHeight = try container.decode(Int.self, forKey: .displayHeight)
                let environment = try container.decode(ComputerUseTool.Environment.self, forKey: .environment)
                self = .computerUse(ComputerUseTool(displayWidth: displayWidth, displayHeight: displayHeight, environment: environment))

            case "function":
                let name = try container.decode(String.self, forKey: .name)
                let parameters = try container.decode([String: AIProxyJSONValue].self, forKey: .parameters)
                let strict = try container.decode(Bool.self, forKey: .strict)
                let description = try container.decodeIfPresent(String.self, forKey: .description)
                self = .function(FunctionTool(name: name, parameters: parameters, strict: strict, description: description))

            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown tool type: \(type)"
                )
            }
        }
    }

    // MARK: - File Search Tool
    nonisolated public struct FileSearchTool: Codable, Sendable {

        // Required
        /// The type of the file search tool. Always `file_search`.
        public let type = "file_search"

        /// The IDs of the vector stores to search.
        public let vectorStoreIDs: [String]

        // Optional
        /// A filter to apply.
        public let filters: FileSearchFilter?

        /// The maximum number of results to return. This number should be between 1 and 50 inclusive.
        public let maxNumResults: Int?

        /// Ranking options for search.
        /// If not specified, the file search tool will use the `auto` ranker and a `score_threshold` of 0.
        public let rankingOptions: RankingOptions?

        private enum CodingKeys: String, CodingKey {
            case type
            case vectorStoreIDs = "vector_store_ids"
            case filters
            case maxNumResults = "max_num_results"
            case rankingOptions = "ranking_options"
        }

        public init(
            vectorStoreIDs: [String],
            filters: FileSearchFilter? = nil,
            maxNumResults: Int? = nil,
            rankingOptions: RankingOptions? = nil
        ) {
            self.vectorStoreIDs = vectorStoreIDs
            self.filters = filters
            self.maxNumResults = maxNumResults
            self.rankingOptions = rankingOptions
        }

        nonisolated public struct RankingOptions: Codable, Sendable {
            /// The ranker to use for the file search.
            public let ranker: String?

            /// The score threshold for the file search, a number between 0 and 1.
            /// Numbers closer to 1 will attempt to return only the most relevant results, but may return fewer results.
            public let scoreThreshold: Double?

            private enum CodingKeys: String, CodingKey {
                case ranker
                case scoreThreshold = "score_threshold"
            }

            public init(ranker: String? = "auto", scoreThreshold: Double? = 0) {
                self.ranker = ranker
                self.scoreThreshold = scoreThreshold
            }
        }
    }

    nonisolated public enum FileSearchFilter: Codable, Sendable {
        case comparison(ComparisonFilter)
        case compound(CompoundFilter)

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .comparison(let filter): try container.encode(filter)
            case .compound(let filter): try container.encode(filter)
            }
        }

        /// A filter used to compare a specified attribute key to a given value using a defined comparison operation.
        nonisolated public struct ComparisonFilter: Codable, Sendable {
            /// The key to compare against the value.
            public let key: String

            /// Specifies the comparison operator: eq, ne, gt, gte, lt, lte
            public let type: ComparisonOperator

            /// The value to compare against the attribute key; supports string, number, or boolean types.
            public let value: AIProxyJSONValue

            public init(key: String, type: ComparisonOperator, value: AIProxyJSONValue) {
                self.key = key
                self.type = type
                self.value = value
            }
        }

        nonisolated public enum ComparisonOperator: String, Codable, Sendable {
            case eq
            case ne
            case gt
            case gte
            case lt
            case lte
        }

        /// Combine multiple filters using `and` or `or`.
        nonisolated public struct CompoundFilter: Codable, Sendable {
            /// Array of filters to combine. Items can be `ComparisonFilter` or `CompoundFilter`.
            public let filters: [FileSearchFilter]

            /// Type of operation: `and` or `or`.
            public let type: CompoundOperator

            public init(filters: [FileSearchFilter], type: CompoundOperator) {
                self.filters = filters
                self.type = type
            }
        }

        nonisolated public enum CompoundOperator: String, Codable, Sendable {
            case and
            case or
        }
    }

    // MARK: - Web Search Tool
    nonisolated public struct WebSearchTool: Codable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case type
            case searchContextSize = "search_context_size"
            case userLocation = "user_location"
        }

        public let type = "web_search"
        public let searchContextSize: SearchContextSize?
        public let userLocation: UserLocation?

        public init(
            searchContextSize: SearchContextSize? = .medium,
            userLocation: UserLocation? = nil
        ) {
            self.searchContextSize = searchContextSize
            self.userLocation = userLocation
        }

        nonisolated public enum SearchContextSize: String, Codable, Sendable {
            case high
            case medium
            case low
        }

        nonisolated public struct UserLocation: Codable, Sendable {
            public var type = "approximate"
            public let city: String?
            public let country: String?
            public let region: String?
            public let timezone: String?

            public init(
                city: String? = nil,
                country: String? = nil,
                region: String? = nil,
                timezone: String? = nil
            ) {
                self.city = city
                self.country = country
                self.region = region
                self.timezone = timezone
            }
        }
    }

    // MARK: - Web Search Tool (Preview)
    // Not including the deprecated message as it causes a compiler warning in our own decoder conformance on OpenAIResponseTool.
    // @available(*, deprecated, message: "Use WebSearchTool instead. WebSearchPreviewTool will be removed in a future version.")
    public typealias WebSearchPreviewTool = WebSearchTool

    // MARK: - Computer Use Tool
    nonisolated public struct ComputerUseTool: Codable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case type
            case displayWidth = "display_width"
            case displayHeight = "display_height"
            case environment
        }

        public let type = "computer_use_preview"
        public let displayWidth: Int
        public let displayHeight: Int
        public let environment: Environment

        public init(
            displayWidth: Int,
            displayHeight: Int,
            environment: Environment
        ) {
            self.displayWidth = displayWidth
            self.displayHeight = displayHeight
            self.environment = environment
        }

        nonisolated public enum Environment: String, Codable, Sendable {
            case browser
            case mac
            case windows
            case ubuntu
        }
    }

    // MARK: - Function Tool
    nonisolated public struct FunctionTool: Codable, Sendable {
        // Required

        /// The name of the function to call.
        public let name: String

        /// A JSON schema object describing the parameters of the function.
        public let parameters: [String: AIProxyJSONValue]

        /// Whether to enforce strict parameter validation. Default true.
        public let strict: Bool

        /// The type of the function tool. Always `function`
        public let type = "function"

        // Optional

        /// A description of the function. Used by the model to determine whether or not to call the function.
        public let description: String?

        private enum CodingKeys: String, CodingKey {
            case description
            case name
            case parameters
            case strict
            case type
        }

        public init(
            name: String,
            parameters: [String: AIProxyJSONValue],
            strict: Bool = true,
            description: String? = nil
        ) {
            self.name = name
            self.parameters = parameters
            self.strict = strict
            self.description = description
        }
    }
}

// MARK: - Reasoning
extension OpenAICreateResponseRequestBody {
    /// Configuration options for reasoning models
    nonisolated public struct Reasoning: Encodable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case effort
            case generateSummary = "generate_summary"
            case summary
        }

        /// Constrains effort on reasoning for reasoning models.
        /// Currently supported values are low, medium, and high.
        /// Reducing reasoning effort can result in faster responses and fewer tokens used on reasoning in a response.
        public let effort: Effort?

        /// Deprecated!
        /// A summary of the reasoning performed by the model. This can be useful for debugging and
        /// understanding the model's reasoning process. One of auto, concise, or detailed.
        ///
        /// I'm removing this deprecation notice, because it seems there is no way to avoid raising
        /// The deprecation warning from within our own initializer.
        /// We still have the runtime log in the initializer to communicate to developers that the field is deprecated.
        /// @available(*, deprecated, message: "This has been renamed to 'summary' by OpenAI")
        public let generateSummary: SummaryType?

        /// A summary of the reasoning performed by the model. This can be useful for debugging and
        /// understanding the model's reasoning process. One of auto, concise, or detailed.
        public let summary: SummaryType?

        public init(
            effort: Effort? = nil,
            generateSummary: SummaryType? = nil,
            summary: SummaryType? = nil
        ) {
            self.effort = effort
            if let summary {
                self.summary = summary
            } else if generateSummary != nil {
               logIf(.warning)?.warning("AIProxy: generateSummary has been renamed to summary by OpenAI, please update your call site.")
               self.summary = generateSummary
            } else {
                self.summary = nil
            }

            self.generateSummary = nil
        }
    }
}

// MARK: - Reasoning Types
extension OpenAICreateResponseRequestBody.Reasoning {
    /// Constrains effort on reasoning for reasoning models. Currently supported values are `none`, `minimal`, `low`, `medium`, and `high`.
    /// Reducing reasoning effort can result in faster responses and fewer tokens used on reasoning in a response.
    ///
    /// gpt-5.1 defaults to `none`, which does not perform reasoning.
    /// The supported reasoning values for gpt-5.1 are `none`, `low`, `medium`, and `high`.
    /// Tool calls are supported for all reasoning values in gpt-5.1.
    /// All models before gpt-5.1 default to `medium` reasoning effort, and do not support `none`.
    /// The gpt-5-pro model defaults to (and only supports) `high` reasoning effort.
    nonisolated public enum Effort: String, Encodable, Sendable {
        case noReasoning = "none"
        case minimal
        case low
        case medium
        case high
        case xhigh
    }

    /// Summary types for reasoning models
    nonisolated public enum SummaryType: String, Encodable, Sendable {
        case auto
        case concise
        case detailed
    }
}

// MARK: - Tool Choice
extension OpenAICreateResponseRequestBody {
    nonisolated public enum ToolChoice: Codable, Sendable {
        case none
        case auto
        case required
        case function(name: String)

        private enum CodingKeys: String, CodingKey {
            case type
            case name
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .none:
                var container = encoder.singleValueContainer()
                try container.encode("none")
            case .auto:
                var container = encoder.singleValueContainer()
                try container.encode("auto")
            case .required:
                var container = encoder.singleValueContainer()
                try container.encode("required")
            case .function(let name):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("function", forKey: .type)
                try container.encode(name, forKey: .name)
            }
        }

        public init(from decoder: Decoder) throws {
            if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                let type = try container.decode(String.self, forKey: .type)
                switch type {
                case "function":
                    let name = try container.decode(String.self, forKey: .name)
                    self = .function(name: name)
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .type,
                        in: container,
                        debugDescription: "Unknown tool choice type: \(type)"
                    )
                }
            } else {
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                switch value {
                case "none": self = .none
                case "auto": self = .auto
                case "required": self = .required
                default:
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Unknown tool choice value: \(value)"
                    )
                }
            }
        }
    }
}
