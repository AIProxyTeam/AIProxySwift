//
//  OpenAIRealtimeConversationItemCreate.swift
//
//
//  Created by Lou Zell on 10/12/24.
//

import Foundation

/// https://platform.openai.com/docs/api-reference/realtime-client-events/conversation/item/create
nonisolated public struct OpenAIRealtimeConversationItemCreate: Encodable {
    public let type = "conversation.item.create"
    public let item: Item

    public init(item: Item) {
        self.item = item
    }
}

// MARK: -
public extension OpenAIRealtimeConversationItemCreate {
    struct Item: Encodable {
        public let type: String
        public let role: String?
        public let content: [Content]?
        public let callID: String?
        public let name: String?
        public let arguments: String?
        public let output: String?

        private enum CodingKeys: String, CodingKey {
            case arguments
            case callID = "call_id"
            case content
            case name
            case output
            case role
            case type
        }

        public init(role: String, text: String) {
            self.type = "message"
            self.role = role
            // The OpenAI Realtime API requires different content types per role:
            //   - user/system: "input_text"
            //   - assistant: "output_text"
            // See: https://platform.openai.com/docs/api-reference/realtime-client-events/conversation/item/create
            let contentType = (role == "assistant") ? "output_text" : "input_text"
            self.content = [Content(type: contentType, text: text)]
            self.callID = nil
            self.name = nil
            self.arguments = nil
            self.output = nil
        }

        public init(
            role: String,
            content: [Content]
        ) {
            self.type = "message"
            self.role = role
            self.content = content
            self.callID = nil
            self.name = nil
            self.arguments = nil
            self.output = nil
        }

        public static func functionCall(
            callID: String,
            name: String,
            arguments: String
        ) -> Item {
            Item(
                type: "function_call",
                role: nil,
                content: nil,
                callID: callID,
                name: name,
                arguments: arguments,
                output: nil
            )
        }

        public static func functionCallOutput(
            callID: String,
            output: String
        ) -> Item {
            Item(
                type: "function_call_output",
                role: nil,
                content: nil,
                callID: callID,
                name: nil,
                arguments: nil,
                output: output
            )
        }

        private init(
            type: String,
            role: String?,
            content: [Content]?,
            callID: String?,
            name: String?,
            arguments: String?,
            output: String?
        ) {
            self.type = type
            self.role = role
            self.content = content
            self.callID = callID
            self.name = name
            self.arguments = arguments
            self.output = output
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(role, forKey: .role)
            try container.encodeIfPresent(content, forKey: .content)
            try container.encodeIfPresent(callID, forKey: .callID)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(arguments, forKey: .arguments)
            try container.encodeIfPresent(output, forKey: .output)
        }
    }
}

// MARK: -
public extension OpenAIRealtimeConversationItemCreate.Item {
    struct Content: Encodable {
        public let type: String
        public let text: String?
        public let audio: String?
        public let itemID: String?
        public let imageURL: String?

        private enum CodingKeys: String, CodingKey {
            case audio
            case imageURL = "image_url"
            case itemID = "item_id"
            case text
            case type
        }

        public init(type: String = "input_text", text: String) {
            self.type = type
            self.text = text
            self.audio = nil
            self.itemID = nil
            self.imageURL = nil
        }

        public static func inputAudio(_ audio: String) -> Content {
            Content(type: "input_audio", text: nil, audio: audio, itemID: nil, imageURL: nil)
        }

        public static func itemReference(_ itemID: String) -> Content {
            Content(type: "item_reference", text: nil, audio: nil, itemID: itemID, imageURL: nil)
        }

        public static func inputImage(url: String) -> Content {
            Content(type: "input_image", text: nil, audio: nil, itemID: nil, imageURL: url)
        }

        private init(
            type: String,
            text: String?,
            audio: String?,
            itemID: String?,
            imageURL: String?
        ) {
            self.type = type
            self.text = text
            self.audio = audio
            self.itemID = itemID
            self.imageURL = imageURL
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(audio, forKey: .audio)
            try container.encodeIfPresent(itemID, forKey: .itemID)
            try container.encodeIfPresent(imageURL, forKey: .imageURL)
        }
    }
}
