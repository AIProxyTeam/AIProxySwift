//
//  OpenAIRealtimeReasoning+Effort.swift
//  AIProxy
//

extension OpenAIRealtimeReasoning {
    nonisolated public enum Effort: String, Encodable, Sendable {
        case minimal
        case low
        case medium
        case high
        case xhigh
    }
}
