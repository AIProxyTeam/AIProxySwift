//
//  OpenAIRealtimeResponsePhase.swift
//  AIProxy
//

public enum OpenAIRealtimeResponsePhase: String, Decodable, Sendable {
    case commentary
    case finalAnswer = "final_answer"
}
