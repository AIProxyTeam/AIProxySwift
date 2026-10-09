//
//  OpenAIRealtimeReasoning.swift
//  AIProxy
//

/// Reasoning effort for OpenAI Realtime Reasoning models such as `gpt-realtime-2`.
/// Encodes as an object containing `effort`, for example `{"effort":"low"}`.
/// Omit the parent configuration's `reasoning` field to leave effort unspecified.
nonisolated public enum OpenAIRealtimeReasoning: String, Encodable, Sendable {
    case minimal
    case low
    case medium
    case high
    case xhigh

    private enum CodingKeys: String, CodingKey {
        case effort
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .effort)
    }
}
