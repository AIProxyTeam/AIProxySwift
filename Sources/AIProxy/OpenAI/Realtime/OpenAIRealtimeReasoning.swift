//
//  OpenAIRealtimeReasoning.swift
//  AIProxy
//

/// Reasoning options for OpenAI Realtime Reasoning models such as `gpt-realtime-2`.
nonisolated public struct OpenAIRealtimeReasoning: Encodable, Sendable {
    /// Constrains effort on Realtime Reasoning models.
    public let effort: Effort?

    public init(effort: Effort? = nil) {
        self.effort = effort
    }
}
