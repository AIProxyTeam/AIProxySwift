//
//  MistralTranscriptionResponseBody.swift
//  AIProxy
//
//  Created by Lou Zell on 7/24/26.
//

import Foundation

/// Response body for Mistral's audio transcription endpoint:
/// https://docs.mistral.ai/api/endpoint/audio/transcriptions#operation-audio_api_v1_transcriptions_post
///
/// ## Contributors
/// Mistral's OpenAPI spec is here:
/// https://raw.githubusercontent.com/mistralai/platform-docs-public/main/openapi.yaml
nonisolated public struct MistralTranscriptionResponseBody: Decodable, Sendable {
    /// The model that produced the transcription.
    public let model: String?

    /// The transcribed text.
    public let text: String?

    /// Detected or requested language of the audio (ISO-639-1, e.g. `en`).
    public let language: String?

    /// Optional timed segments of the transcription.
    public let segments: [Segment]?

    /// Token and audio usage for the request.
    public let usage: Usage?
}

// MARK: - Segment
extension MistralTranscriptionResponseBody {
    /// A timed segment of transcribed audio.
    /// See `TranscriptionSegmentChunk` in Mistral's API reference.
    nonisolated public struct Segment: Decodable, Sendable {
        /// Always `transcription_segment` when present.
        public let type: String?

        /// Text content of the segment.
        public let text: String?

        /// Start time of the segment in seconds.
        public let start: Double?

        /// End time of the segment in seconds.
        public let end: Double?

        /// Optional confidence score for the segment.
        public let score: Double?

        /// Optional speaker label when diarization is enabled.
        public let speakerID: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case start
            case end
            case score
            case speakerID = "speaker_id"
        }
    }
}

// MARK: - Usage
extension MistralTranscriptionResponseBody {
    /// Usage statistics returned with a transcription response.
    nonisolated public struct Usage: Decodable, Sendable {
        /// Number of tokens in the prompt.
        public let promptTokens: Int?

        /// Number of tokens in the generated completion.
        public let completionTokens: Int?

        /// Total number of tokens used in the request (prompt + completion).
        public let totalTokens: Int?

        /// Duration of the input audio in seconds, when reported by the API.
        public let promptAudioSeconds: Int?

        private enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case promptAudioSeconds = "prompt_audio_seconds"
        }
    }
}
