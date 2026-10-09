//
//  MistralTranscriptionStreamingEventTests.swift
//  AIProxyTests
//

import Foundation
import Testing
@testable import AIProxy

struct MistralTranscriptionStreamingEventTests {

    @Test
    func textDeltaIsDecodable() throws {
        let event = try decode(#"{"type":"transcription.text.delta","text":"Hello"}"#)

        guard case .textDelta(let payload) = event else {
            Issue.record("Expected textDelta")
            return
        }
        #expect(payload.text == "Hello")
    }

    @Test
    func languageIsDecodable() throws {
        let event = try decode(#"{"type":"transcription.language","audio_language":"en"}"#)

        guard case .language(let payload) = event else {
            Issue.record("Expected language")
            return
        }
        #expect(payload.audioLanguage == "en")
    }

    @Test
    func segmentIsDecodable() throws {
        let event = try decode(
            #"""
            {
              "type": "transcription.segment",
              "text": "Yesterday it was 35 degrees in Barcelona.",
              "start": 1.0,
              "end": 9.5,
              "speaker_id": null
            }
            """#
        )

        guard case .segment(let payload) = event else {
            Issue.record("Expected segment")
            return
        }
        #expect(payload.text == "Yesterday it was 35 degrees in Barcelona.")
        #expect(payload.start == 1.0)
        #expect(payload.end == 9.5)
        #expect(payload.speakerID == nil)
    }

    @Test
    func doneIsDecodable() throws {
        let event = try decode(
            #"""
            {
              "model": "voxtral-mini-latest",
              "text": "Yesterday it was 35 degrees in Barcelona, but today the temperature will go down to minus 20 degrees.",
              "language": null,
              "segments": [
                {
                  "text": "Yesterday it was 35 degrees in Barcelona, but today the temperature will go down to minus 20 degrees.",
                  "start": 1.0,
                  "end": 9.5,
                  "speaker_id": null,
                  "type": "transcription_segment"
                }
              ],
              "usage": {
                "prompt_audio_seconds": 11,
                "prompt_tokens": 4,
                "total_tokens": 413,
                "completion_tokens": 34,
                "prompt_tokens_details": {
                  "cached_tokens": 1,
                  "audio_tokens": 375
                }
              },
              "finish_reason": null,
              "type": "transcription.done"
            }
            """#
        )

        guard case .done(let payload) = event else {
            Issue.record("Expected done")
            return
        }
        #expect(payload.model == "voxtral-mini-latest")
        #expect(payload.text?.contains("Barcelona") == true)
        #expect(payload.language == nil)
        #expect(payload.segments?.count == 1)
        #expect(payload.segments?.first?.start == 1.0)
        #expect(payload.usage?.promptAudioSeconds == 11)
        #expect(payload.usage?.totalTokens == 413)
    }

    @Test
    func unknownStreamingEventDecodesAsFutureProof() throws {
        let event = try decode(#"{"type":"transcription.unknown.event","foo":1}"#)
        guard case .futureProof = event else {
            Issue.record("Expected futureProof")
            return
        }
    }
}

private func decode(_ json: String) throws -> MistralTranscriptionStreamingEvent {
    try MistralTranscriptionStreamingEvent.deserialize(from: json)
}
