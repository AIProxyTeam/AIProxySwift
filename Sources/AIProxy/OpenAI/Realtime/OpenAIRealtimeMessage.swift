//
//  OpenAIRealtimeMessage.swift
//  AIProxy
//
//  Created by Lou Zell on 12/29/24.
//  Update by harr-sudo 05/05/2025
//  Update by Richard Das 03/16/2025

import Foundation

nonisolated public enum OpenAIRealtimeMessage: Decodable, Sendable {
    case error(OpenAIRealtimeErrorEvent)
    case sessionCreated // "session.created"
    case sessionUpdated // "session.updated"
    case responseCreated(OpenAIRealtimeResponseCreatedEvent) // "response.created"
    case responseAudioDelta(OpenAIRealtimeResponseAudioDeltaEvent) // "response.audio.delta"
    case inputAudioBufferSpeechStarted(OpenAIRealtimeInputAudioBufferSpeechStartedEvent) // "input_audio_buffer.speech_started"
    case inputAudioBufferSpeechStopped(OpenAIRealtimeInputAudioBufferSpeechStoppedEvent) // "input_audio_buffer.speech_stopped"
    case inputAudioBufferCommitted(OpenAIRealtimeInputAudioBufferCommittedEvent) // "input_audio_buffer.committed"
    case inputAudioBufferTimeoutTriggered(OpenAIRealtimeInputAudioBufferTimeoutTriggeredEvent) // "input_audio_buffer.timeout_triggered"
    case inputAudioBufferDTMFEventReceived(OpenAIRealtimeInputAudioBufferDTMFEventReceivedEvent) // "input_audio_buffer.dtmf_event_received"
    case conversationItemCreated(OpenAIRealtimeConversationItemCreatedEvent) // "conversation.item.created"
    case conversationItemAdded(OpenAIRealtimeConversationItemAddedEvent) // "conversation.item.added"
    case conversationItemDone(OpenAIRealtimeConversationItemDoneEvent) // "conversation.item.done"
    case responseFunctionCallArgumentsDone(OpenAIRealtimeResponseFunctionCallArgumentsDoneEvent) // "response.function_call_arguments.done"
    case responseOutputItemAdded(OpenAIRealtimeResponseOutputItemAddedEvent) // "response.output_item.added"
    case responseOutputItemDone(OpenAIRealtimeResponseOutputItemDoneEvent) // "response.output_item.done"
    case responseContentPartAdded(OpenAIRealtimeResponseContentPartAddedEvent) // "response.content_part.added"
    case responseContentPartDone(OpenAIRealtimeResponseContentPartDoneEvent) // "response.content_part.done"
    case responseAudioDone(OpenAIRealtimeResponseAudioDoneEvent) // "response.audio.done" / "response.output_audio.done"
    case responseDone(OpenAIRealtimeResponseDoneEvent) // "response.done"
    case rateLimitsUpdated(OpenAIRealtimeRateLimitsUpdatedEvent) // "rate_limits.updated"

    case responseTranscriptDelta(OpenAIRealtimeResponseTranscriptDeltaEvent) // "response.audio_transcript.delta" / "response.output_audio_transcript.delta"
    case responseTranscriptDone(OpenAIRealtimeResponseTranscriptDoneEvent) // "response.audio_transcript.done" / "response.output_audio_transcript.done"
    case responseTextDelta(OpenAIRealtimeResponseTextDeltaEvent) // "response.text.delta" / "response.output_text.delta"
    case responseTextDone(OpenAIRealtimeResponseTextDoneEvent) // "response.text.done" / "response.output_text.done"
    case inputAudioBufferTranscript(OpenAIRealtimeInputAudioBufferTranscriptEvent) // "input_audio_buffer.transcript"
    case inputAudioTranscriptionDelta(OpenAIRealtimeInputAudioTranscriptionDeltaEvent) // "conversation.item.input_audio_transcription.delta"
    case inputAudioTranscriptionCompleted(OpenAIRealtimeInputAudioTranscriptionCompletedEvent) // "conversation.item.input_audio_transcription.completed"
    case inputAudioTranscriptionFailed(OpenAIRealtimeInputAudioTranscriptionFailedEvent) // "conversation.item.input_audio_transcription.failed"
    case inputAudioTranscriptionSegment(OpenAIRealtimeInputAudioTranscriptionSegmentEvent) // "conversation.item.input_audio_transcription.segment"

    case futureProof

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "error":
            self = .error(try OpenAIRealtimeErrorEvent(from: decoder))
        case "session.created":
            self = .sessionCreated
        case "session.updated":
            self = .sessionUpdated
        case "response.created":
            self = .responseCreated(try OpenAIRealtimeResponseCreatedEvent(from: decoder))
        case "response.audio.delta", "response.output_audio.delta":
            self = .responseAudioDelta(try OpenAIRealtimeResponseAudioDeltaEvent(from: decoder))
        case "input_audio_buffer.speech_started":
            self = .inputAudioBufferSpeechStarted(try OpenAIRealtimeInputAudioBufferSpeechStartedEvent(from: decoder))
        case "input_audio_buffer.speech_stopped":
            self = .inputAudioBufferSpeechStopped(try OpenAIRealtimeInputAudioBufferSpeechStoppedEvent(from: decoder))
        case "input_audio_buffer.committed":
            self = .inputAudioBufferCommitted(try OpenAIRealtimeInputAudioBufferCommittedEvent(from: decoder))
        case "input_audio_buffer.timeout_triggered":
            self = .inputAudioBufferTimeoutTriggered(try OpenAIRealtimeInputAudioBufferTimeoutTriggeredEvent(from: decoder))
        case "input_audio_buffer.dtmf_event_received":
            self = .inputAudioBufferDTMFEventReceived(try OpenAIRealtimeInputAudioBufferDTMFEventReceivedEvent(from: decoder))
        case "conversation.item.created":
            self = .conversationItemCreated(try OpenAIRealtimeConversationItemCreatedEvent(from: decoder))
        case "conversation.item.added":
            self = .conversationItemAdded(try OpenAIRealtimeConversationItemAddedEvent(from: decoder))
        case "conversation.item.done":
            self = .conversationItemDone(try OpenAIRealtimeConversationItemDoneEvent(from: decoder))
        case "response.function_call_arguments.done":
            self = .responseFunctionCallArgumentsDone(try OpenAIRealtimeResponseFunctionCallArgumentsDoneEvent(from: decoder))
        case "response.output_item.added":
            self = .responseOutputItemAdded(try OpenAIRealtimeResponseOutputItemAddedEvent(from: decoder))
        case "response.output_item.done":
            self = .responseOutputItemDone(try OpenAIRealtimeResponseOutputItemDoneEvent(from: decoder))
        case "response.content_part.added":
            self = .responseContentPartAdded(try OpenAIRealtimeResponseContentPartAddedEvent(from: decoder))
        case "response.content_part.done":
            self = .responseContentPartDone(try OpenAIRealtimeResponseContentPartDoneEvent(from: decoder))
        case "response.audio.done", "response.output_audio.done":
            self = .responseAudioDone(try OpenAIRealtimeResponseAudioDoneEvent(from: decoder))
        case "response.done":
            self = .responseDone(try OpenAIRealtimeResponseDoneEvent(from: decoder))
        case "rate_limits.updated":
            self = .rateLimitsUpdated(try OpenAIRealtimeRateLimitsUpdatedEvent(from: decoder))
        case "response.audio_transcript.delta", "response.output_audio_transcript.delta":
            self = .responseTranscriptDelta(try OpenAIRealtimeResponseTranscriptDeltaEvent(from: decoder))
        case "response.audio_transcript.done", "response.output_audio_transcript.done":
            self = .responseTranscriptDone(try OpenAIRealtimeResponseTranscriptDoneEvent(from: decoder))
        case "response.text.delta", "response.output_text.delta":
            self = .responseTextDelta(try OpenAIRealtimeResponseTextDeltaEvent(from: decoder))
        case "response.text.done", "response.output_text.done":
            self = .responseTextDone(try OpenAIRealtimeResponseTextDoneEvent(from: decoder))
        case "input_audio_buffer.transcript":
            self = .inputAudioBufferTranscript(try OpenAIRealtimeInputAudioBufferTranscriptEvent(from: decoder))
        case "conversation.item.input_audio_transcription.delta":
            self = .inputAudioTranscriptionDelta(try OpenAIRealtimeInputAudioTranscriptionDeltaEvent(from: decoder))
        case "conversation.item.input_audio_transcription.completed":
            self = .inputAudioTranscriptionCompleted(try OpenAIRealtimeInputAudioTranscriptionCompletedEvent(from: decoder))
        case "conversation.item.input_audio_transcription.failed":
            self = .inputAudioTranscriptionFailed(try OpenAIRealtimeInputAudioTranscriptionFailedEvent(from: decoder))
        case "conversation.item.input_audio_transcription.segment":
            self = .inputAudioTranscriptionSegment(try OpenAIRealtimeInputAudioTranscriptionSegmentEvent(from: decoder))
        default:
            logIf(.info)?.info("Received unknown OpenAI realtime event of type \(type).")
            self = .futureProof
        }
    }
}

public struct OpenAIRealtimeErrorEvent: Decodable, Sendable {
    public let errorBody: String?

    private struct ErrorObject: Decodable {
        let message: String?
        let type: String?
        let code: String?
    }

    private enum CodingKeys: String, CodingKey {
        case error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let errorString = try? container.decode(String.self, forKey: .error) {
            self.errorBody = errorString
            return
        }
        if let errorObject = try container.decodeIfPresent(ErrorObject.self, forKey: .error) {
            if let message = errorObject.message {
                self.errorBody = message
            } else if let type = errorObject.type, let code = errorObject.code {
                self.errorBody = "\(type): \(code)"
            } else {
                self.errorBody = errorObject.type ?? errorObject.code
            }
            return
        }
        self.errorBody = nil
    }
}

public struct OpenAIRealtimeResponseCreatedEvent: Decodable, Sendable {
    public let responseID: String?
    public let eventID: String?

    private struct ResponseBody: Decodable {
        let id: String?
    }

    private enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case response
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let response = try container.decodeIfPresent(ResponseBody.self, forKey: .response)
        self.responseID = response?.id
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseAudioDeltaEvent: Decodable, Sendable {
    public let base64Audio: String
    public let responseID: String?

    private enum CodingKeys: String, CodingKey {
        case base64Audio = "delta"
        case responseID = "response_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.base64Audio = try container.decode(String.self, forKey: .base64Audio)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
    }
}

public struct OpenAIRealtimeInputAudioBufferSpeechStartedEvent: Decodable, Sendable {
    public let itemID: String?
    public let audioStartMS: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case audioStartMS = "audio_start_ms"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.audioStartMS = container.decodeFlexibleIntIfPresent(forKey: .audioStartMS)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioBufferSpeechStoppedEvent: Decodable, Sendable {
    public let itemID: String?
    public let audioEndMS: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case audioEndMS = "audio_end_ms"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.audioEndMS = container.decodeFlexibleIntIfPresent(forKey: .audioEndMS)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioBufferCommittedEvent: Decodable, Sendable {
    public let itemID: String?
    public let previousItemID: String?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case previousItemID = "previous_item_id"
        case eventID = "event_id"
    }
}

public struct OpenAIRealtimeInputAudioBufferTimeoutTriggeredEvent: Decodable, Sendable {
    public let itemID: String?
    public let audioStartMS: Int?
    public let audioEndMS: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case audioStartMS = "audio_start_ms"
        case audioEndMS = "audio_end_ms"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.audioStartMS = container.decodeFlexibleIntIfPresent(forKey: .audioStartMS)
        self.audioEndMS = container.decodeFlexibleIntIfPresent(forKey: .audioEndMS)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioBufferDTMFEventReceivedEvent: Decodable, Sendable {
    public let event: String?
    public let receivedAt: Double?

    private enum CodingKeys: String, CodingKey {
        case event
        case receivedAt = "received_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.event = try container.decodeIfPresent(String.self, forKey: .event)
        self.receivedAt = container.decodeFlexibleDoubleIfPresent(forKey: .receivedAt)
    }
}

public struct OpenAIRealtimeConversationItemCreatedEvent: Decodable, Sendable {
    public let itemID: String?
    public let previousItemID: String?
    public let role: String?
    public let phase: OpenAIRealtimeResponsePhase?
    public let eventID: String?

    private struct ItemBody: Decodable {
        let id: String?
        let role: String?
        let phase: OpenAIRealtimeResponsePhase?
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case previousItemID = "previous_item_id"
        case eventID = "event_id"
        case item
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        let fallbackItemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.itemID = item?.id ?? fallbackItemID
        self.previousItemID = try container.decodeIfPresent(String.self, forKey: .previousItemID)
        self.role = item?.role
        self.phase = item?.phase
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public typealias OpenAIRealtimeConversationItemAddedEvent = OpenAIRealtimeConversationItemCreatedEvent
public typealias OpenAIRealtimeConversationItemDoneEvent = OpenAIRealtimeConversationItemCreatedEvent

public struct OpenAIRealtimeResponseFunctionCallArgumentsDoneEvent: Decodable, Sendable {
    public let name: String
    public let arguments: String
    public let callID: String

    private enum CodingKeys: String, CodingKey {
        case name
        case arguments
        case callID = "call_id"
    }
}

public struct OpenAIRealtimeResponseOutputItemAddedEvent: Decodable, Sendable {
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let phase: OpenAIRealtimeResponsePhase?
    public let eventID: String?

    private struct ItemBody: Decodable {
        let id: String?
        let phase: OpenAIRealtimeResponsePhase?
    }

    private enum CodingKeys: String, CodingKey {
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case eventID = "event_id"
        case item
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        let fallbackItemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.itemID = item?.id ?? fallbackItemID
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.phase = item?.phase
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseOutputItemDoneEvent: Decodable, Sendable {
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let phase: OpenAIRealtimeResponsePhase?
    public let transcript: String?
    public let eventID: String?

    private struct ItemBody: Decodable {
        struct ContentBody: Decodable {
            let transcript: String?
        }
        let id: String?
        let phase: OpenAIRealtimeResponsePhase?
        let content: [ContentBody]?
    }

    private enum CodingKeys: String, CodingKey {
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case eventID = "event_id"
        case item
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        let fallbackItemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.itemID = item?.id ?? fallbackItemID
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.phase = item?.phase
        self.transcript = item?.content?.first(where: { ($0.transcript?.isEmpty == false) })?.transcript
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseContentPartAddedEvent: Decodable, Sendable {
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let contentIndex: Int?
    public let part: OpenAIRealtimeContentPart?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case part
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.part = try container.decodeIfPresent(OpenAIRealtimeContentPart.self, forKey: .part)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseContentPartDoneEvent: Decodable, Sendable {
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let contentIndex: Int?
    public let transcript: String?
    public let part: OpenAIRealtimeContentPart?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case part
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let part = try container.decodeIfPresent(OpenAIRealtimeContentPart.self, forKey: .part)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.transcript = part?.transcript
        self.part = part
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseAudioDoneEvent: Decodable, Sendable {
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let contentIndex: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseDoneEvent: Decodable, Sendable {
    public let responseID: String?
    public let conversationID: String?
    public let status: String?
    public let output: [OpenAIRealtimeResponseOutputItem]?
    public let usage: OpenAIRealtimeResponseUsage?
    public let eventID: String?

    private struct ResponseBody: Decodable {
        let id: String?
        let conversationID: String?
        let status: String?
        let output: [OpenAIRealtimeResponseOutputItem]?
        let usage: OpenAIRealtimeResponseUsage?

        private enum CodingKeys: String, CodingKey {
            case id
            case conversationID = "conversation_id"
            case status
            case output
            case usage
        }
    }

    private enum CodingKeys: String, CodingKey {
        case response
        case eventID = "event_id"
        case responseID = "response_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let response = try container.decodeIfPresent(ResponseBody.self, forKey: .response)
        let fallbackResponseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.responseID = response?.id ?? fallbackResponseID
        self.conversationID = response?.conversationID
        self.status = response?.status
        self.output = response?.output
        self.usage = response?.usage
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseUsage: Decodable, Sendable {
    /// The Swift properties use Responses-style names while decoding Realtime wire keys like `input_token_details`.
    public let inputTokens: Int?
    public let inputTokensDetails: InputTokensDetails?
    public let outputTokens: Int?
    public let outputTokensDetails: OutputTokensDetails?
    public let totalTokens: Int?

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case inputTokensDetails = "input_token_details"
        case outputTokens = "output_tokens"
        case outputTokensDetails = "output_token_details"
        case totalTokens = "total_tokens"
    }
}

extension OpenAIRealtimeResponseUsage {
    nonisolated public struct InputTokensDetails: Decodable, Sendable {
        public let audioTokens: Int?
        public let cachedTokens: Int?
        public let cachedTokensDetails: CachedTokensDetails?
        public let imageTokens: Int?
        public let textTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case audioTokens = "audio_tokens"
            case cachedTokens = "cached_tokens"
            case cachedTokensDetails = "cached_tokens_details"
            case imageTokens = "image_tokens"
            case textTokens = "text_tokens"
        }
    }

    nonisolated public struct CachedTokensDetails: Decodable, Sendable {
        public let audioTokens: Int?
        public let imageTokens: Int?
        public let textTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case audioTokens = "audio_tokens"
            case imageTokens = "image_tokens"
            case textTokens = "text_tokens"
        }
    }

    nonisolated public struct OutputTokensDetails: Decodable, Sendable {
        public let audioTokens: Int?
        public let textTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case audioTokens = "audio_tokens"
            case textTokens = "text_tokens"
        }
    }
}

public struct OpenAIRealtimeRateLimitsUpdatedEvent: Decodable, Sendable {
    public let rateLimits: [OpenAIRealtimeRateLimit]
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
        case eventID = "event_id"
    }
}

public struct OpenAIRealtimeResponseTranscriptDeltaEvent: Decodable, Sendable {
    public let delta: String
    public let responseID: String?
    public let itemID: String?
    public let contentIndex: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case delta
        case responseID = "response_id"
        case itemID = "item_id"
        case contentIndex = "content_index"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.delta = try container.decode(String.self, forKey: .delta)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseTranscriptDoneEvent: Decodable, Sendable {
    public let transcript: String
    public let responseID: String?
    public let itemID: String?
    public let contentIndex: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case transcript
        case responseID = "response_id"
        case itemID = "item_id"
        case contentIndex = "content_index"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.transcript = try container.decode(String.self, forKey: .transcript)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseTextDeltaEvent: Decodable, Sendable {
    public let delta: String
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let contentIndex: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case delta
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.delta = try container.decode(String.self, forKey: .delta)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeResponseTextDoneEvent: Decodable, Sendable {
    public let text: String
    public let responseID: String?
    public let itemID: String?
    public let outputIndex: Int?
    public let contentIndex: Int?
    public let eventID: String?

    private enum CodingKeys: String, CodingKey {
        case text
        case responseID = "response_id"
        case itemID = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.responseID = try container.decodeIfPresent(String.self, forKey: .responseID)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        self.outputIndex = container.decodeFlexibleIntIfPresent(forKey: .outputIndex)
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioBufferTranscriptEvent: Decodable, Sendable {
    public let transcript: String
}

public struct OpenAIRealtimeInputAudioTranscriptionDeltaEvent: Decodable, Sendable {
    /// The text delta. OpenAI documents this as optional; it may be absent in edge cases.
    public let delta: String?
    public let itemID: String?
    public let contentIndex: Int?
    public let logprobs: [OpenAITranscriptionLogprob]?
    public let eventID: String?

    private struct ItemBody: Decodable {
        let id: String?
    }

    private enum CodingKeys: String, CodingKey {
        case delta
        case itemID = "item_id"
        case item
        case contentIndex = "content_index"
        case logprobs
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        self.delta = try container.decodeIfPresent(String.self, forKey: .delta)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID) ?? item?.id
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.logprobs = try container.decodeIfPresent([OpenAITranscriptionLogprob].self, forKey: .logprobs)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioTranscriptionCompletedEvent: Decodable, Sendable {
    public let transcript: String
    public let itemID: String?
    public let contentIndex: Int?
    public let usage: OpenAITranscriptionUsage?
    public let logprobs: [OpenAITranscriptionLogprob]?
    public let eventID: String?

    private struct ItemBody: Decodable {
        let id: String?
    }

    private enum CodingKeys: String, CodingKey {
        case transcript
        case itemID = "item_id"
        case item
        case contentIndex = "content_index"
        case usage
        case logprobs
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        self.transcript = try container.decode(String.self, forKey: .transcript)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID) ?? item?.id
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.usage = try container.decodeIfPresent(OpenAITranscriptionUsage.self, forKey: .usage)
        self.logprobs = try container.decodeIfPresent([OpenAITranscriptionLogprob].self, forKey: .logprobs)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioTranscriptionFailedEvent: Decodable, Sendable {
    public let itemID: String?
    public let contentIndex: Int?
    public let error: ErrorBody?
    public let eventID: String?

    private struct ItemBody: Decodable {
        let id: String?
    }

    public struct ErrorBody: Decodable, Sendable {
        public let code: String?
        public let message: String?
        public let param: String?
        public let type: String?
    }

    private enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case item
        case contentIndex = "content_index"
        case error
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID) ?? item?.id
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.error = try container.decodeIfPresent(ErrorBody.self, forKey: .error)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeInputAudioTranscriptionSegmentEvent: Decodable, Sendable {
    public let id: String
    public let itemID: String?
    public let contentIndex: Int?
    public let start: Double?
    public let end: Double?
    public let text: String
    public let speaker: String?
    public let eventID: String?

    private struct ItemBody: Decodable {
        let id: String?
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case itemID = "item_id"
        case item
        case contentIndex = "content_index"
        case start
        case end
        case text
        case speaker
        case eventID = "event_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let item = try container.decodeIfPresent(ItemBody.self, forKey: .item)
        self.id = try container.decode(String.self, forKey: .id)
        self.itemID = try container.decodeIfPresent(String.self, forKey: .itemID) ?? item?.id
        self.contentIndex = container.decodeFlexibleIntIfPresent(forKey: .contentIndex)
        self.start = container.decodeFlexibleDoubleIfPresent(forKey: .start)
        self.end = container.decodeFlexibleDoubleIfPresent(forKey: .end)
        self.text = try container.decode(String.self, forKey: .text)
        self.speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
        self.eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
    }
}

public struct OpenAIRealtimeContentPart: Decodable, Sendable {
    public let type: String?
    public let audio: String?
    public let text: String?
    public let transcript: String?
}

public struct OpenAIRealtimeRateLimit: Decodable, Sendable {
    public let name: String?
    public let limit: Int?
    public let remaining: Int?
    public let resetSeconds: Double?

    private enum CodingKeys: String, CodingKey {
        case name
        case limit
        case remaining
        case resetSeconds = "reset_seconds"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.limit = container.decodeFlexibleIntIfPresent(forKey: .limit)
        self.remaining = container.decodeFlexibleIntIfPresent(forKey: .remaining)
        self.resetSeconds = container.decodeFlexibleDoubleIfPresent(forKey: .resetSeconds)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? self.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? self.decodeIfPresent(String.self, forKey: key), let int = Int(value) {
            return int
        }
        if let value = try? self.decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? self.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? self.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? self.decodeIfPresent(String.self, forKey: key), let double = Double(value) {
            return double
        }
        return nil
    }
}
