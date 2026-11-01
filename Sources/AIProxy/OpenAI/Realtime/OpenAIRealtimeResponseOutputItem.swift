//
//  OpenAIRealtimeResponseOutputItem.swift
//  AIProxy
//

public struct OpenAIRealtimeResponseOutputItem: Decodable, Sendable {
    public let id: String?
    public let phase: OpenAIRealtimeResponsePhase?
    public let content: [Content]?

    public var transcript: String? {
        content?.first(where: { ($0.transcript?.isEmpty == false) })?.transcript
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case phase
        case content
    }
}
