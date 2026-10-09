//
//  OpenAIRealtimeSessionConfiguration.swift
//  AIProxy
//

/// Represents OpenAI's `RealtimeSessionCreateRequest` type, which is a member of the `session.update` event:
/// https://developers.openai.com/api/reference/resources/realtime/client-events#session.update
nonisolated public struct OpenAIRealtimeSessionConfiguration: Encodable, Sendable {
    public let include: [IncludeField]?
    public let type: OpenAIRealtimeSessionConfiguration.SessionType
    public let inputAudioFormat: OpenAIRealtimeSessionConfiguration.AudioFormat?
    public let inputAudioNoiseReduction: InputAudioNoiseReduction?
    public let inputAudioTranscription: InputAudioTranscription?
    public let instructions: String?
    public let maxOutputTokens: OpenAIRealtimeSessionConfiguration.MaxOutputTokens?
    public let model: String?
    public let outputModalities: [OpenAIRealtimeSessionConfiguration.Modality]?
    public let outputAudioFormat: OpenAIRealtimeSessionConfiguration.AudioFormat?

    /// The speed of the model's spoken response as a multiple of the original speed.
    /// 1.0 is the default speed. 0.25 is the minimum speed. 1.5 is the maximum speed.
    /// This value can only be changed in between model turns, not while a response is in progress.
    ///
    /// This parameter is a post-processing adjustment to the audio after it is generated, it's also possible to prompt the model to speak faster or slower.
    public let speed: Float?
    public let tools: [Tool]?
    public let toolChoice: ToolChoice?
    public let turnDetection: TurnDetection?
    public let voice: Voice?
    public let prompt: Prompt?
    public let tracing: Tracing?
    public let truncation: Truncation?
    /// Optional reasoning settings for models that support Realtime Reasoning.
    public let reasoning: OpenAIRealtimeReasoning?
    /// Whether the model may call multiple tools in parallel. Omitted when nil.
    public let parallelToolCalls: Bool?

    public init(
        include: [IncludeField]? = nil,
        type: OpenAIRealtimeSessionConfiguration.SessionType = .realtime,
        inputAudioFormat: OpenAIRealtimeSessionConfiguration.AudioFormat? = nil,
        inputAudioNoiseReduction: InputAudioNoiseReduction? = nil,
        inputAudioTranscription: InputAudioTranscription? = nil,
        instructions: String? = nil,
        maxOutputTokens: OpenAIRealtimeSessionConfiguration.MaxOutputTokens? = nil,
        maxResponseOutputTokens: OpenAIRealtimeSessionConfiguration.MaxOutputTokens? = nil,
        model: String? = nil,
        modalities: [OpenAIRealtimeSessionConfiguration.Modality]? = nil,
        outputModalities: [OpenAIRealtimeSessionConfiguration.Modality]? = nil,
        outputAudioFormat: OpenAIRealtimeSessionConfiguration.AudioFormat? = nil,
        speed: Float? = 1.0,
        temperature: Double? = nil, // Deprecated in the current Realtime API
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        turnDetection: TurnDetection? = nil,
        voice: Voice? = nil,
        prompt: Prompt? = nil,
        tracing: Tracing? = nil,
        truncation: Truncation? = nil,
        reasoning: OpenAIRealtimeReasoning? = nil,
        parallelToolCalls: Bool? = nil
    ) {
        var resolvedModalities = modalities
        if let modalities, Set(modalities) == Set([.audio, .text]) {
            logIf(.warning)?.error("OpenAI realtime no longer accepts [.audio, .text] as modalities. Switching to [.audio].")
            resolvedModalities = [.audio]
        }
        if temperature != nil {
            logIf(.warning)?.warning("OpenAI realtime no longer accepts temperature in the session.update event.")
        }
        if let speed {
            if !(0.25...1.5).contains(speed) {
                logIf(.warning)?.warning("OpenAI realtime does not support speeds outside of the range [0.25, 1.5].")
            }
        }
        self.include = include
        self.type = type
        self.inputAudioFormat = inputAudioFormat
        self.inputAudioNoiseReduction = inputAudioNoiseReduction
        self.inputAudioTranscription = inputAudioTranscription
        self.instructions = instructions
        self.maxOutputTokens = maxOutputTokens ?? maxResponseOutputTokens
        self.model = model
        self.outputModalities = outputModalities ?? resolvedModalities
        self.outputAudioFormat = outputAudioFormat
        self.speed = speed
        self.tools = tools
        self.toolChoice = toolChoice
        self.turnDetection = turnDetection
        self.voice = voice
        self.prompt = prompt
        self.tracing = tracing
        self.truncation = truncation
        self.reasoning = reasoning
        self.parallelToolCalls = parallelToolCalls
    }

    public static func voiceWithWebSearch(
        voice: Voice = .builtin("alloy"),
        searchContextSize: OpenAICreateResponseRequestBody.WebSearchTool.SearchContextSize = .medium
    ) -> OpenAIRealtimeSessionConfiguration {
        OpenAIRealtimeSessionConfiguration(
            tools: [.webSearch(.init(searchContextSize: searchContextSize))],
            toolChoice: .auto,
            voice: voice
        )
    }
}


extension OpenAIRealtimeSessionConfiguration {
    nonisolated public enum IncludeField: String, Encodable, Sendable {
        case inputAudioTranscriptionLogprobs = "item.input_audio_transcription.logprobs"
    }

    nonisolated public struct InputAudioNoiseReduction: Encodable, Sendable {
        public let type: NoiseReductionType
        public init(type: NoiseReductionType) {
            self.type = type
        }
    }

    nonisolated public enum NoiseReductionType: String, Encodable, Sendable {
        case nearField = "near_field"
        case farField = "far_field"
    }

    nonisolated public struct InputAudioTranscription: Encodable, Sendable {
        public let language: String?
        public let model: String?
        public let prompt: String?
        public init(language: String? = nil, model: String? = nil, prompt: String? = nil) {
            self.language = language
            self.model = model
            self.prompt = prompt
        }
    }

    nonisolated public enum Voice: Encodable, Sendable {
        case builtin(String)
        case custom(id: String)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .builtin(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .custom(let id):
                var container = encoder.container(keyedBy: CustomVoiceCodingKeys.self)
                try container.encode(id, forKey: .id)
            }
        }

        private enum CustomVoiceCodingKeys: String, CodingKey {
            case id
        }
    }

    nonisolated public struct Prompt: Encodable, Sendable {
        public let id: String
        public let variables: [String: AIProxyJSONValue]?
        public let version: String?

        public init(
            id: String,
            variables: [String: AIProxyJSONValue]? = nil,
            version: String? = nil
        ) {
            self.id = id
            self.variables = variables
            self.version = version
        }
    }

    nonisolated public enum Tracing: Encodable, Sendable {
        case auto
        case configuration(TracingConfiguration)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .auto:
                var container = encoder.singleValueContainer()
                try container.encode("auto")
            case .configuration(let configuration):
                try configuration.encode(to: encoder)
            }
        }
    }

    nonisolated public struct TracingConfiguration: Encodable, Sendable {
        public let groupID: String?
        public let metadata: [String: AIProxyJSONValue]?
        public let workflowName: String?

        private enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case metadata
            case workflowName = "workflow_name"
        }

        public init(
            groupID: String? = nil,
            metadata: [String: AIProxyJSONValue]? = nil,
            workflowName: String? = nil
        ) {
            self.groupID = groupID
            self.metadata = metadata
            self.workflowName = workflowName
        }
    }

    nonisolated public enum Truncation: Encodable, Sendable {
        case auto
        case disabled
        case retentionRatio(RetentionRatioTruncation)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .auto:
                var container = encoder.singleValueContainer()
                try container.encode("auto")
            case .disabled:
                var container = encoder.singleValueContainer()
                try container.encode("disabled")
            case .retentionRatio(let truncation):
                try truncation.encode(to: encoder)
            }
        }
    }

    nonisolated public struct RetentionRatioTruncation: Encodable, Sendable {
        public let retentionRatio: Double
        public let tokenLimits: TokenLimits?
        public let type = "retention_ratio"

        private enum CodingKeys: String, CodingKey {
            case retentionRatio = "retention_ratio"
            case tokenLimits = "token_limits"
            case type
        }

        public init(
            retentionRatio: Double,
            tokenLimits: TokenLimits? = nil
        ) {
            self.retentionRatio = retentionRatio
            self.tokenLimits = tokenLimits
        }
    }

    nonisolated public struct TokenLimits: Encodable, Sendable {
        public let postInstructions: Int?

        private enum CodingKeys: String, CodingKey {
            case postInstructions = "post_instructions"
        }

        public init(postInstructions: Int? = nil) {
            self.postInstructions = postInstructions
        }
    }

    nonisolated public enum Tool: Encodable, Sendable {
        case function(FunctionTool)
        case mcp(MCPTool)
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

    nonisolated public struct FunctionTool: Encodable, Sendable {
        public let name: String
        public let description: String
        public let parameters: [String: AIProxyJSONValue]

        public init(name: String, description: String, parameters: [String: AIProxyJSONValue]) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }

        private enum CodingKeys: String, CodingKey {
            case name
            case description
            case parameters
            case type
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("function", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            try container.encode(parameters, forKey: .parameters)
        }
    }

    nonisolated public struct MCPTool: Encodable, Sendable {
        public let serverLabel: String
        public let allowedTools: AllowedTools?
        public let authorization: String?
        public let connectorID: String?
        public let deferLoading: Bool?
        public let headers: [String: String]?
        public let requireApproval: RequireApproval?
        public let serverDescription: String?
        public let serverURL: String?

        private enum CodingKeys: String, CodingKey {
            case allowedTools = "allowed_tools"
            case authorization
            case connectorID = "connector_id"
            case deferLoading = "defer_loading"
            case headers
            case name
            case requireApproval = "require_approval"
            case serverDescription = "server_description"
            case serverLabel = "server_label"
            case serverURL = "server_url"
            case type
        }

        public init(
            serverLabel: String,
            allowedTools: AllowedTools? = nil,
            authorization: String? = nil,
            connectorID: String? = nil,
            deferLoading: Bool? = nil,
            headers: [String: String]? = nil,
            requireApproval: RequireApproval? = nil,
            serverDescription: String? = nil,
            serverURL: String? = nil
        ) {
            self.serverLabel = serverLabel
            self.allowedTools = allowedTools
            self.authorization = authorization
            self.connectorID = connectorID
            self.deferLoading = deferLoading
            self.headers = headers
            self.requireApproval = requireApproval
            self.serverDescription = serverDescription
            self.serverURL = serverURL
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("mcp", forKey: .type)
            try container.encode(serverLabel, forKey: .serverLabel)
            try container.encodeIfPresent(allowedTools, forKey: .allowedTools)
            try container.encodeIfPresent(authorization, forKey: .authorization)
            try container.encodeIfPresent(connectorID, forKey: .connectorID)
            try container.encodeIfPresent(deferLoading, forKey: .deferLoading)
            try container.encodeIfPresent(headers, forKey: .headers)
            try container.encodeIfPresent(requireApproval, forKey: .requireApproval)
            try container.encodeIfPresent(serverDescription, forKey: .serverDescription)
            try container.encodeIfPresent(serverURL, forKey: .serverURL)
        }
    }

    nonisolated public enum AllowedTools: Encodable, Sendable {
        case names([String])
        case filter(ToolFilter)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .names(let names):
                var container = encoder.singleValueContainer()
                try container.encode(names)
            case .filter(let filter):
                try filter.encode(to: encoder)
            }
        }
    }

    nonisolated public struct ToolFilter: Encodable, Sendable {
        public let readOnly: Bool?
        public let toolNames: [String]?

        private enum CodingKeys: String, CodingKey {
            case readOnly = "read_only"
            case toolNames = "tool_names"
        }

        public init(readOnly: Bool? = nil, toolNames: [String]? = nil) {
            self.readOnly = readOnly
            self.toolNames = toolNames
        }
    }

    nonisolated public enum RequireApproval: Encodable, Sendable {
        case always
        case never
        case filter(ApprovalFilter)

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .always:
                var container = encoder.singleValueContainer()
                try container.encode("always")
            case .never:
                var container = encoder.singleValueContainer()
                try container.encode("never")
            case .filter(let filter):
                try filter.encode(to: encoder)
            }
        }
    }

    nonisolated public struct ApprovalFilter: Encodable, Sendable {
        public let always: ToolFilter?
        public let never: ToolFilter?

        public init(always: ToolFilter? = nil, never: ToolFilter? = nil) {
            self.always = always
            self.never = never
        }
    }

    nonisolated public enum ToolChoice: Encodable, Sendable {
        case none
        case auto
        case required
        case function(name: String)
        case mcp(serverLabel: String, name: String?)

        private enum CodingKeys: String, CodingKey {
            case name
            case serverLabel = "server_label"
            case type
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
            case .mcp(let serverLabel, let name):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("mcp", forKey: .type)
                try container.encode(serverLabel, forKey: .serverLabel)
                try container.encodeIfPresent(name, forKey: .name)
            }
        }
    }

    nonisolated public enum TurnDetection: Encodable, Sendable {
        case serverVAD(ServerVAD)
        case semanticVAD(SemanticVAD)

        private enum CodingKeys: String, CodingKey {
            case createResponse = "create_response"
            case eagerness
            case idleTimeoutMs = "idle_timeout_ms"
            case interruptResponse = "interrupt_response"
            case prefixPaddingMs = "prefix_padding_ms"
            case silenceDurationMs = "silence_duration_ms"
            case threshold
            case type
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .serverVAD(let serverVAD):
                try container.encode("server_vad", forKey: .type)
                try container.encodeIfPresent(serverVAD.createResponse, forKey: .createResponse)
                try container.encodeIfPresent(serverVAD.idleTimeoutMs, forKey: .idleTimeoutMs)
                try container.encodeIfPresent(serverVAD.interruptResponse, forKey: .interruptResponse)
                try container.encodeIfPresent(serverVAD.prefixPaddingMs, forKey: .prefixPaddingMs)
                try container.encodeIfPresent(serverVAD.silenceDurationMs, forKey: .silenceDurationMs)
                try container.encodeIfPresent(serverVAD.threshold, forKey: .threshold)
            case .semanticVAD(let semanticVAD):
                try container.encode("semantic_vad", forKey: .type)
                try container.encodeIfPresent(semanticVAD.createResponse, forKey: .createResponse)
                try container.encodeIfPresent(semanticVAD.interruptResponse, forKey: .interruptResponse)
                try container.encodeIfPresent(semanticVAD.eagerness, forKey: .eagerness)
            }
        }

    }

    nonisolated public struct ServerVAD: Encodable, Sendable {
        public let createResponse: Bool?
        public let idleTimeoutMs: Int?
        public let interruptResponse: Bool?
        public let prefixPaddingMs: Int?
        public let silenceDurationMs: Int?
        public let threshold: Double?

        public init(
            createResponse: Bool? = nil,
            idleTimeoutMs: Int? = nil,
            interruptResponse: Bool? = nil,
            prefixPaddingMs: Int? = nil,
            silenceDurationMs: Int? = nil,
            threshold: Double? = nil
        ) {
            self.createResponse = createResponse
            self.idleTimeoutMs = idleTimeoutMs
            self.interruptResponse = interruptResponse
            self.prefixPaddingMs = prefixPaddingMs
            self.silenceDurationMs = silenceDurationMs
            self.threshold = threshold
        }
    }

    nonisolated public struct SemanticVAD: Encodable, Sendable {
        public let createResponse: Bool?
        public let eagerness: Eagerness?
        public let interruptResponse: Bool?

        public init(
            createResponse: Bool? = nil,
            eagerness: Eagerness? = nil,
            interruptResponse: Bool? = nil
        ) {
            self.createResponse = createResponse
            self.eagerness = eagerness
            self.interruptResponse = interruptResponse
        }
    }

    nonisolated public enum Eagerness: String, Encodable, Sendable {
        case low
        case medium
        case high
        case auto
    }
}


// MARK: -
extension OpenAIRealtimeSessionConfiguration {
    nonisolated public enum SessionType: String, Encodable, Sendable {
        case realtime
        case transcription
    }
}


// MARK: - Legacy callsite compatibility
extension OpenAIRealtimeSessionConfiguration {
    public typealias MaxResponseOutputTokens = MaxOutputTokens
}

extension OpenAIRealtimeSessionConfiguration.Voice: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .builtin(value)
    }
}

extension OpenAIRealtimeSessionConfiguration.TurnDetection {
    /// Legacy initializer kept for source compatibility with call sites that
    /// build `TurnDetection(type: .semanticVAD(eagerness: ...))`.
    public init(type: DetectionType) {
        switch type {
        case .serverVAD(let prefixPaddingMs, let silenceDurationMs, let threshold):
            self = .serverVAD(.init(
                prefixPaddingMs: prefixPaddingMs,
                silenceDurationMs: silenceDurationMs,
                threshold: threshold
            ))
        case .semanticVAD(let eagerness):
            self = .semanticVAD(.init(eagerness: eagerness))
        }
    }

    public enum DetectionType: Sendable {
        case serverVAD(prefixPaddingMs: Int, silenceDurationMs: Int, threshold: Double)
        case semanticVAD(eagerness: OpenAIRealtimeSessionConfiguration.Eagerness)
    }
}

// MARK: -
extension OpenAIRealtimeSessionConfiguration {
    nonisolated public enum MaxOutputTokens: Encodable, Sendable {
        case int(Int)
        case infinite

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .int(let value):
                try container.encode(value)
            case .infinite:
                try container.encode("inf")
            }
        }
    }
}

// MARK: -
/// The format of input audio. Options are `pcm16`, `g711_ulaw`, or `g711_alaw`.
extension OpenAIRealtimeSessionConfiguration {
    nonisolated public enum AudioFormat: String, Encodable, Sendable {
        case pcm16
        case g711Ulaw = "g711_ulaw"
        case g711Alaw = "g711_alaw"
    }
}

// MARK: -
/// The format of input audio. Options are `pcm16`, `g711_ulaw`, or `g711_alaw`.
extension OpenAIRealtimeSessionConfiguration {
    nonisolated public enum Modality: String, Encodable, Sendable {
        case audio
        case text
    }
}

// MARK: - Session update wire encoding
private struct OpenAIRealtimeSessionConfigurationWire: Encodable, Sendable {
    let include: [OpenAIRealtimeSessionConfiguration.IncludeField]?
    let type: OpenAIRealtimeSessionConfiguration.SessionType
    let inputAudioFormat: OpenAIRealtimeSessionConfiguration.AudioFormat?
    let inputAudioNoiseReduction: OpenAIRealtimeSessionConfiguration.InputAudioNoiseReduction?
    let inputAudioTranscription: OpenAIRealtimeSessionConfiguration.InputAudioTranscription?
    let instructions: String?
    let maxOutputTokens: OpenAIRealtimeSessionConfiguration.MaxOutputTokens?
    let model: String?
    let outputModalities: [OpenAIRealtimeSessionConfiguration.Modality]?
    let outputAudioFormat: OpenAIRealtimeSessionConfiguration.AudioFormat?
    let speed: Float?
    let tools: [OpenAIRealtimeSessionConfiguration.Tool]?
    let toolChoice: OpenAIRealtimeSessionConfiguration.ToolChoice?
    let turnDetection: OpenAIRealtimeSessionConfiguration.TurnDetection?
    let voice: OpenAIRealtimeSessionConfiguration.Voice?
    let prompt: OpenAIRealtimeSessionConfiguration.Prompt?
    let tracing: OpenAIRealtimeSessionConfiguration.Tracing?
    let truncation: OpenAIRealtimeSessionConfiguration.Truncation?
    let reasoning: OpenAIRealtimeReasoning?
    let parallelToolCalls: Bool?

    init(_ configuration: OpenAIRealtimeSessionConfiguration) {
        self.include = configuration.include
        self.type = configuration.type
        self.inputAudioFormat = configuration.inputAudioFormat
        self.inputAudioNoiseReduction = configuration.inputAudioNoiseReduction
        self.inputAudioTranscription = configuration.inputAudioTranscription
        self.instructions = configuration.instructions
        self.maxOutputTokens = configuration.maxOutputTokens
        self.model = configuration.model
        self.outputModalities = configuration.outputModalities
        self.outputAudioFormat = configuration.outputAudioFormat
        self.speed = configuration.speed
        self.tools = configuration.tools
        self.toolChoice = configuration.toolChoice
        self.turnDetection = configuration.turnDetection
        self.voice = configuration.voice
        self.prompt = configuration.prompt
        self.tracing = configuration.tracing
        self.truncation = configuration.truncation
        self.reasoning = configuration.reasoning
        self.parallelToolCalls = configuration.parallelToolCalls
    }

    private enum CodingKeys: String, CodingKey {
        case include
        case type
        case audio
        case instructions
        case maxOutputTokens = "max_output_tokens"
        case model
        case outputModalities = "output_modalities"
        case prompt
        case reasoning
        case parallelToolCalls = "parallel_tool_calls"
        case tracing
        case truncation
        case tools
        case toolChoice = "tool_choice"
    }

    private enum AudioCodingKeys: String, CodingKey {
        case input
        case output
    }

    private enum InputAudioCodingKeys: String, CodingKey {
        case format
        case noiseReduction = "noise_reduction"
        case transcription
        case turnDetection = "turn_detection"
    }

    private enum OutputAudioCodingKeys: String, CodingKey {
        case format
        case speed
        case voice
    }

    private struct RealtimeAudioFormatWire: Encodable, Sendable {
        let type: String
        let rate: Int?

        init(_ format: OpenAIRealtimeSessionConfiguration.AudioFormat) {
            switch format {
            case .pcm16:
                self.type = "audio/pcm"
                self.rate = 24000
            case .g711Ulaw:
                self.type = "audio/pcmu"
                self.rate = nil
            case .g711Alaw:
                self.type = "audio/pcma"
                self.rate = nil
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(include, forKey: .include)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encodeIfPresent(maxOutputTokens, forKey: .maxOutputTokens)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(outputModalities, forKey: .outputModalities)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
        try container.encodeIfPresent(parallelToolCalls, forKey: .parallelToolCalls)
        try container.encodeIfPresent(tracing, forKey: .tracing)
        try container.encodeIfPresent(truncation, forKey: .truncation)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)

        let hasInputAudioConfig =
            inputAudioFormat != nil || inputAudioNoiseReduction != nil || inputAudioTranscription != nil || turnDetection != nil
        let hasOutputAudioConfig =
            outputAudioFormat != nil || speed != nil || voice != nil

        if hasInputAudioConfig || hasOutputAudioConfig {
            var audioContainer = container.nestedContainer(
                keyedBy: AudioCodingKeys.self,
                forKey: .audio
            )
            if hasInputAudioConfig {
                var inputContainer = audioContainer.nestedContainer(
                    keyedBy: InputAudioCodingKeys.self,
                    forKey: .input
                )
                if let inputAudioFormat {
                    try inputContainer.encode(
                        RealtimeAudioFormatWire(inputAudioFormat),
                        forKey: .format
                    )
                }
                try inputContainer.encodeIfPresent(inputAudioNoiseReduction, forKey: .noiseReduction)
                try inputContainer.encodeIfPresent(inputAudioTranscription, forKey: .transcription)
                try inputContainer.encodeIfPresent(turnDetection, forKey: .turnDetection)
            }
            if hasOutputAudioConfig {
                var outputContainer = audioContainer.nestedContainer(
                    keyedBy: OutputAudioCodingKeys.self,
                    forKey: .output
                )
                if let outputAudioFormat {
                    try outputContainer.encode(
                        RealtimeAudioFormatWire(outputAudioFormat),
                        forKey: .format
                    )
                }
                try outputContainer.encodeIfPresent(speed, forKey: .speed)
                try outputContainer.encodeIfPresent(voice, forKey: .voice)
            }
        }
    }
}

extension OpenAIRealtimeSessionConfiguration {
    public func encode(to encoder: Encoder) throws {
        try OpenAIRealtimeSessionConfigurationWire(self).encode(to: encoder)
    }
}
