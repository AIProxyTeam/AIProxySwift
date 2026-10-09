//
//  MistralTranscriptionStreamingEvent.swift
//  AIProxy
//
//  Created by Lou Zell on 7/25/26.
//

import Foundation

/// Represents a server-sent event from Mistral's streaming audio transcription endpoint:
/// https://docs.mistral.ai/api/endpoint/audio/transcriptions#operation-audio_api_v1_transcriptions_post_stream
///
/// SSE lines look like:
/// ```
/// event: transcription.text.delta
/// data: {"type":"transcription.text.delta","text":"Hello"}
/// ```
///
/// AIProxy deserializes the JSON from each `data:` line.
///
/// ## Contributors
/// Mistral's OpenAPI spec is here:
/// https://raw.githubusercontent.com/mistralai/platform-docs-public/main/openapi.yaml
nonisolated public enum MistralTranscriptionStreamingEvent: Decodable, Sendable {
    case textDelta(TextDelta)
    case language(Language)
    case segment(Segment)
    case done(Done)
    case futureProof

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "transcription.text.delta":
            self = .textDelta(try TextDelta(from: decoder))
        case "transcription.language":
            self = .language(try Language(from: decoder))
        case "transcription.segment":
            self = .segment(try Segment(from: decoder))
        case "transcription.done":
            self = .done(try Done(from: decoder))
        default:
            logIf(.info)?.info("Received unknown Mistral transcription stream event of type \(type).")
            self = .futureProof
        }
    }
}

// MARK: -
extension MistralTranscriptionStreamingEvent {
    /// Incremental transcript text (`transcription.text.delta`).
    nonisolated public struct TextDelta: Decodable, Sendable {
        /// Incremental transcript text for this event.
        public let text: String?
    }

    /// Detected audio language (`transcription.language`).
    nonisolated public struct Language: Decodable, Sendable {
        /// Detected language of the audio (ISO-639-1, e.g. `en`).
        public let audioLanguage: String?

        private enum CodingKeys: String, CodingKey {
            case audioLanguage = "audio_language"
        }
    }

    /// A timed segment emitted during streaming (`transcription.segment`).
    nonisolated public struct Segment: Decodable, Sendable {
        /// Text content of the segment.
        public let text: String?

        /// Start time of the segment in seconds.
        public let start: Double?

        /// End time of the segment in seconds.
        public let end: Double?

        /// Optional speaker label when diarization is enabled.
        public let speakerID: String?

        private enum CodingKeys: String, CodingKey {
            case text
            case start
            case end
            case speakerID = "speaker_id"
        }
    }

    /// Final transcription payload (`transcription.done`).
    nonisolated public struct Done: Decodable, Sendable {
        /// The model that produced the transcription.
        public let model: String?

        /// The full transcribed text.
        public let text: String?

        /// Detected or requested language of the audio (ISO-639-1, e.g. `en`).
        public let language: String?

        /// Optional timed segments of the transcription.
        public let segments: [MistralTranscriptionResponseBody.Segment]?

        /// Token and audio usage for the request.
        public let usage: MistralTranscriptionResponseBody.Usage?
    }
}
