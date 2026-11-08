//
//  OpenAIRealtimeResponseOutputItem+Content.swift
//  AIProxy
//

extension OpenAIRealtimeResponseOutputItem {
    public struct Content: Decodable, Sendable {
        public let type: String?
        public let text: String?
        public let transcript: String?
    }
}
