//
//  OpenAIRealtimeMessageTests.swift
//  AIProxyTests
//

import Foundation
import Testing
@testable import AIProxy

/// Realtime server events: verifies selected canonical event names decode as expected.
/// Selected legacy event type aliases remain decodable for compatibility.
/// This suite is intentionally not a full realtime event matrix.
struct OpenAIRealtimeMessageTests {

    @Test
    func testResponseOutputAudioDeltaIsDecodable() throws {
        let event = try decode(
            #"{"type":"response.output_audio.delta","delta":"AQID","response_id":"resp_1","event_id":"event_1"}"#
        )

        guard case .responseAudioDelta(let payload) = event else {
            Issue.record("Expected responseAudioDelta")
            return
        }
        #expect(payload.base64Audio == "AQID")
        #expect(payload.responseID == "resp_1")
    }

    @Test
    func testConversationItemAddedAndDoneAreDecodable() throws {
        let added = try decode(
            #"{"type":"conversation.item.added","event_id":"event_2","item":{"id":"msg_1","role":"assistant"},"previous_item_id":"msg_0"}"#
        )
        let done = try decode(
            #"{"type":"conversation.item.done","event_id":"event_3","item":{"id":"msg_1","role":"assistant"},"previous_item_id":"msg_0"}"#
        )

        guard case .conversationItemAdded(let addedPayload) = added else {
            Issue.record("Expected conversationItemAdded")
            return
        }
        #expect(addedPayload.itemID == "msg_1")
        #expect(addedPayload.role == "assistant")
        #expect(addedPayload.previousItemID == "msg_0")

        guard case .conversationItemDone(let donePayload) = done else {
            Issue.record("Expected conversationItemDone")
            return
        }
        #expect(donePayload.itemID == "msg_1")
        #expect(donePayload.role == "assistant")
        #expect(donePayload.previousItemID == "msg_0")
    }

    @Test
    func testInputAudioBufferTimeoutTriggeredIsDecodable() throws {
        let event = try decode(
            #"{"type":"input_audio_buffer.timeout_triggered","event_id":"event_4","item_id":"item_1","audio_start_ms":1200,"audio_end_ms":2400}"#
        )

        guard case .inputAudioBufferTimeoutTriggered(let payload) = event else {
            Issue.record("Expected inputAudioBufferTimeoutTriggered")
            return
        }
        #expect(payload.itemID == "item_1")
        #expect(payload.audioStartMS == 1200)
        #expect(payload.audioEndMS == 2400)
        #expect(payload.eventID == "event_4")
    }

    @Test
    func testInputAudioBufferDTMFEventReceivedIsDecodable() throws {
        let event = try decode(
            #"{"type":"input_audio_buffer.dtmf_event_received","event":"5","received_at":1743985938}"#
        )

        guard case .inputAudioBufferDTMFEventReceived(let payload) = event else {
            Issue.record("Expected inputAudioBufferDTMFEventReceived")
            return
        }
        #expect(payload.event == "5")
        #expect(payload.receivedAt == 1743985938)
    }

    @Test
    func testTranscriptDeltasRemainDecodableAcrossInterleavedLifecycleEvents() throws {
        let lines: [String] = [
            #"{"type":"conversation.item.added","event_id":"event_10","item":{"id":"assistant_item","role":"assistant"},"previous_item_id":"user_item"}"#,
            #"{"type":"response.output_audio_transcript.delta","event_id":"event_11","response_id":"resp_9","item_id":"assistant_item","content_index":0,"delta":"Hel"}"#,
            #"{"type":"conversation.item.done","event_id":"event_12","item":{"id":"user_item","role":"user"},"previous_item_id":"older_item"}"#,
            #"{"type":"response.output_audio_transcript.delta","event_id":"event_13","response_id":"resp_9","item_id":"assistant_item","content_index":0,"delta":"lo"}"#,
            #"{"type":"response.output_audio_transcript.done","event_id":"event_14","response_id":"resp_9","item_id":"assistant_item","content_index":0,"transcript":"Hello"}"#,
        ]

        var assembled = ""
        var finalTranscript: String?

        for line in lines {
            let event = try decode(line)
            switch event {
            case .responseTranscriptDelta(let payload):
                assembled += payload.delta
            case .responseTranscriptDone(let payload):
                finalTranscript = payload.transcript
            default:
                continue
            }
        }

        #expect(assembled == "Hello")
        #expect(finalTranscript == "Hello")
    }

    @Test
    func testResponseOutputTextEventsAreDecodable() throws {
        let deltaEvent = try decode(
            #"{"type":"response.output_text.delta","event_id":"event_21","response_id":"resp_11","item_id":"assistant_item","output_index":0,"content_index":0,"delta":"Hi"}"#
        )
        let doneEvent = try decode(
            #"{"type":"response.output_text.done","event_id":"event_22","response_id":"resp_11","item_id":"assistant_item","output_index":0,"content_index":0,"text":"Hi there"}"#
        )

        guard case .responseTextDelta(let deltaPayload) = deltaEvent else {
            Issue.record("Expected responseTextDelta")
            return
        }
        #expect(deltaPayload.delta == "Hi")
        #expect(deltaPayload.itemID == "assistant_item")

        guard case .responseTextDone(let donePayload) = doneEvent else {
            Issue.record("Expected responseTextDone")
            return
        }
        #expect(donePayload.text == "Hi there")
        #expect(donePayload.itemID == "assistant_item")
    }

    @Test
    func testLegacyResponseTextEventsRemainDecodableForCompatibility() throws {
        let deltaEvent = try decode(
            #"{"type":"response.text.delta","event_id":"event_23","response_id":"resp_12","item_id":"assistant_item","output_index":0,"content_index":0,"delta":"A"}"#
        )
        let doneEvent = try decode(
            #"{"type":"response.text.done","event_id":"event_24","response_id":"resp_12","item_id":"assistant_item","output_index":0,"content_index":0,"text":"AB"}"#
        )

        guard case .responseTextDelta(let deltaPayload) = deltaEvent else {
            Issue.record("Expected legacy responseTextDelta")
            return
        }
        #expect(deltaPayload.delta == "A")

        guard case .responseTextDone(let donePayload) = doneEvent else {
            Issue.record("Expected legacy responseTextDone")
            return
        }
        #expect(donePayload.text == "AB")
    }

    @Test
    func testResponseDoneUsageIsDecodable() throws {
        let event = try decode(
            #"""
            {
              "type": "response.done",
              "event_id": "event_30",
              "response": {
                "id": "resp_30",
                "conversation_id": "conv_30",
                "status": "completed",
                "usage": {
                  "input_tokens": 141,
                  "input_token_details": {
                    "text_tokens": 18,
                    "audio_tokens": 91,
                    "image_tokens": 12,
                    "cached_tokens": 20,
                    "cached_tokens_details": {
                      "text_tokens": 7,
                      "audio_tokens": 11,
                      "image_tokens": 2
                    }
                  },
                  "output_tokens": 84,
                  "output_token_details": {
                    "text_tokens": 24,
                    "audio_tokens": 60
                  },
                  "total_tokens": 225
                }
              }
            }
            """#
        )

        guard case .responseDone(let payload) = event else {
            Issue.record("Expected responseDone")
            return
        }
        #expect(payload.responseID == "resp_30")
        #expect(payload.conversationID == "conv_30")
        #expect(payload.status == "completed")
        #expect(payload.usage?.inputTokens == 141)
        #expect(payload.usage?.inputTokensDetails?.textTokens == 18)
        #expect(payload.usage?.inputTokensDetails?.audioTokens == 91)
        #expect(payload.usage?.inputTokensDetails?.imageTokens == 12)
        #expect(payload.usage?.inputTokensDetails?.cachedTokens == 20)
        #expect(payload.usage?.inputTokensDetails?.cachedTokensDetails?.textTokens == 7)
        #expect(payload.usage?.inputTokensDetails?.cachedTokensDetails?.audioTokens == 11)
        #expect(payload.usage?.inputTokensDetails?.cachedTokensDetails?.imageTokens == 2)
        #expect(payload.usage?.outputTokens == 84)
        #expect(payload.usage?.outputTokensDetails?.textTokens == 24)
        #expect(payload.usage?.outputTokensDetails?.audioTokens == 60)
        #expect(payload.usage?.totalTokens == 225)
    }

    @Test
    func testResponseDoneDecodesPhasedOutput() throws {
        let event = try decode(
            #"""
            {
              "type": "response.done",
              "event_id": "event_40",
              "response": {
                "id": "resp_40",
                "conversation_id": "conv_40",
                "status": "completed",
                "output": [
                  {
                    "id": "msg_commentary",
                    "phase": "commentary",
                    "content": [
                      {
                        "type": "output_audio",
                        "transcript": "I'll check that now."
                      }
                    ]
                  },
                  {
                    "id": "msg_final",
                    "phase": "final_answer",
                    "content": [
                      {
                        "type": "output_audio",
                        "transcript": "The appointment is confirmed."
                      }
                    ]
                  }
                ]
              }
            }
            """#
        )

        guard case .responseDone(let payload) = event else {
            Issue.record("Expected responseDone")
            return
        }
        #expect(payload.output?.count == 2)
        #expect(payload.output?.first?.phase == .commentary)
        #expect(payload.output?.first?.transcript == "I'll check that now.")
        #expect(payload.output?.last?.phase == .finalAnswer)
        #expect(payload.output?.last?.transcript == "The appointment is confirmed.")
    }

    @Test
    func testResponseOutputItemDoneDecodesPhase() throws {
        let event = try decode(
            #"""
            {
              "type": "response.output_item.done",
              "event_id": "event_41",
              "response_id": "resp_41",
              "output_index": 0,
              "item": {
                "id": "msg_41",
                "phase": "final_answer",
                "content": [
                  {
                    "type": "output_audio",
                    "transcript": "Done."
                  }
                ]
              }
            }
            """#
        )

        guard case .responseOutputItemDone(let payload) = event else {
            Issue.record("Expected responseOutputItemDone")
            return
        }
        #expect(payload.itemID == "msg_41")
        #expect(payload.phase == .finalAnswer)
        #expect(payload.transcript == "Done.")
    }

    @Test
    func testResponseOutputItemAddedDecodesPhase() throws {
        let event = try decode(
            #"""
            {
              "type": "response.output_item.added",
              "event_id": "event_42",
              "response_id": "resp_42",
              "output_index": 0,
              "item": {
                "id": "msg_42",
                "phase": "commentary"
              }
            }
            """#
        )

        guard case .responseOutputItemAdded(let payload) = event else {
            Issue.record("Expected responseOutputItemAdded")
            return
        }
        #expect(payload.itemID == "msg_42")
        #expect(payload.phase == .commentary)
    }

    @Test
    func testConversationItemAddedDecodesPhase() throws {
        let event = try decode(
            #"""
            {
              "type": "conversation.item.added",
              "event_id": "event_43",
              "item": {
                "id": "msg_43",
                "role": "assistant",
                "phase": "final_answer"
              }
            }
            """#
        )

        guard case .conversationItemAdded(let payload) = event else {
            Issue.record("Expected conversationItemAdded")
            return
        }
        #expect(payload.itemID == "msg_43")
        #expect(payload.role == "assistant")
        #expect(payload.phase == .finalAnswer)
    }

    @Test
    func testConversationItemCreatedAndDoneDecodePhase() throws {
        let created = try decode(
            #"""
            {
              "type": "conversation.item.created",
              "event_id": "event_44",
              "item": {
                "id": "msg_44",
                "role": "assistant",
                "phase": "commentary"
              }
            }
            """#
        )
        let done = try decode(
            #"""
            {
              "type": "conversation.item.done",
              "event_id": "event_45",
              "item": {
                "id": "msg_45",
                "role": "assistant",
                "phase": "final_answer"
              }
            }
            """#
        )

        guard case .conversationItemCreated(let createdPayload) = created else {
            Issue.record("Expected conversationItemCreated")
            return
        }
        #expect(createdPayload.itemID == "msg_44")
        #expect(createdPayload.phase == .commentary)

        guard case .conversationItemDone(let donePayload) = done else {
            Issue.record("Expected conversationItemDone")
            return
        }
        #expect(donePayload.itemID == "msg_45")
        #expect(donePayload.phase == .finalAnswer)
    }

    @Test
    func testInputAudioTranscriptionDeltaLogprobsAreDecodable() throws {
        let event = try decode(
            #"{"type":"conversation.item.input_audio_transcription.delta","event_id":"event_31","item_id":"item_31","content_index":0,"delta":"Hel","logprobs":[{"token":"Hel","bytes":[72,101,108],"logprob":-0.21}]}"#
        )

        guard case .inputAudioTranscriptionDelta(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionDelta")
            return
        }
        #expect(payload.itemID == "item_31")
        #expect(payload.contentIndex == 0)
        #expect(payload.delta == "Hel")
        #expect(payload.logprobs?.count == 1)
        #expect(payload.logprobs?.first?.token == "Hel")
        #expect(payload.logprobs?.first?.bytes == [72, 101, 108])
    }

    @Test
    func testInputAudioTranscriptionDeltaDecodesWithoutDelta() throws {
        let event = try decode(
            #"{"type":"conversation.item.input_audio_transcription.delta","event_id":"event_36","item_id":"item_36","content_index":0,"logprobs":[{"token":"x","bytes":[120],"logprob":-0.1}]}"#
        )

        guard case .inputAudioTranscriptionDelta(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionDelta")
            return
        }
        #expect(payload.delta == nil)
        #expect(payload.itemID == "item_36")
        #expect(payload.logprobs?.first?.token == "x")
    }

    @Test
    func testInputAudioTranscriptionCompletedTokenUsageIsDecodable() throws {
        let event = try decode(
            #"""
            {
              "type": "conversation.item.input_audio_transcription.completed",
              "event_id": "event_32",
              "item_id": "item_32",
              "content_index": 0,
              "transcript": "Hello there",
              "usage": {
                "type": "tokens",
                "input_tokens": 12,
                "input_token_details": {
                  "audio_tokens": 10,
                  "text_tokens": 2
                },
                "output_tokens": 4,
                "total_tokens": 16
              },
              "logprobs": [
                {
                  "token": "Hello",
                  "bytes": [72, 101, 108, 108, 111],
                  "logprob": -0.12
                }
              ]
            }
            """#
        )

        guard case .inputAudioTranscriptionCompleted(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionCompleted")
            return
        }
        #expect(payload.itemID == "item_32")
        #expect(payload.contentIndex == 0)
        #expect(payload.transcript == "Hello there")
        switch payload.usage?.type {
        case .tokens?:
            break
        default:
            Issue.record("Expected token-based transcription usage")
        }
        #expect(payload.usage?.inputTokens == 12)
        #expect(payload.usage?.inputTokensDetails?.audioTokens == 10)
        #expect(payload.usage?.inputTokensDetails?.textTokens == 2)
        #expect(payload.usage?.outputTokens == 4)
        #expect(payload.usage?.totalTokens == 16)
        #expect(payload.logprobs?.first?.token == "Hello")
        #expect(payload.logprobs?.first?.bytes == [72, 101, 108, 108, 111])
    }

    @Test
    func testInputAudioTranscriptionCompletedDurationUsageIsDecodable() throws {
        let event = try decode(
            #"{"type":"conversation.item.input_audio_transcription.completed","event_id":"event_33","item":{"id":"item_33"},"content_index":0,"transcript":"A short phrase","usage":{"type":"duration","seconds":3.75}}"#
        )

        guard case .inputAudioTranscriptionCompleted(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionCompleted")
            return
        }
        #expect(payload.itemID == "item_33")
        #expect(payload.transcript == "A short phrase")
        switch payload.usage?.type {
        case .duration?:
            break
        default:
            Issue.record("Expected duration-based transcription usage")
        }
        #expect(payload.usage?.seconds == 3.75)
        #expect(payload.usage?.inputTokens == nil)
    }

    @Test
    func testInputAudioTranscriptionFailedIsDecodable() throws {
        let event = try decode(
            #"""
            {
              "type": "conversation.item.input_audio_transcription.failed",
              "event_id": "event_34",
              "item_id": "item_34",
              "content_index": 0,
              "error": {
                "type": "invalid_request_error",
                "code": "unsupported_audio",
                "message": "Audio could not be transcribed.",
                "param": "audio"
              }
            }
            """#
        )

        guard case .inputAudioTranscriptionFailed(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionFailed")
            return
        }
        #expect(payload.eventID == "event_34")
        #expect(payload.itemID == "item_34")
        #expect(payload.contentIndex == 0)
        #expect(payload.error?.type == "invalid_request_error")
        #expect(payload.error?.code == "unsupported_audio")
        #expect(payload.error?.message == "Audio could not be transcribed.")
        #expect(payload.error?.param == "audio")
    }

    @Test
    func testInputAudioTranscriptionSegmentIsDecodable() throws {
        let event = try decode(
            #"""
            {
              "type": "conversation.item.input_audio_transcription.segment",
              "event_id": "event_35",
              "id": "seg_35",
              "item": {
                "id": "item_35"
              },
              "content_index": 0,
              "start": 1.2,
              "end": 4.8,
              "text": "Thanks for calling.",
              "speaker": "agent"
            }
            """#
        )

        guard case .inputAudioTranscriptionSegment(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionSegment")
            return
        }
        #expect(payload.eventID == "event_35")
        #expect(payload.id == "seg_35")
        #expect(payload.itemID == "item_35")
        #expect(payload.contentIndex == 0)
        #expect(payload.start == 1.2)
        #expect(payload.end == 4.8)
        #expect(payload.text == "Thanks for calling.")
        #expect(payload.speaker == "agent")
    }

    @Test
    func testInputAudioTranscriptionSegmentDecodesTopLevelItemId() throws {
        let event = try decode(
            #"""
            {
              "type": "conversation.item.input_audio_transcription.segment",
              "event_id": "event_37",
              "id": "seg_37",
              "item_id": "item_37",
              "content_index": 0,
              "start": 0.5,
              "end": 2.5,
              "text": "Hello.",
              "speaker": "A"
            }
            """#
        )

        guard case .inputAudioTranscriptionSegment(let payload) = event else {
            Issue.record("Expected inputAudioTranscriptionSegment")
            return
        }
        #expect(payload.itemID == "item_37")
        #expect(payload.id == "seg_37")
        #expect(payload.text == "Hello.")
        #expect(payload.speaker == "A")
    }

    private func decode(_ json: String) throws -> OpenAIRealtimeMessage {
        try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: Data(json.utf8))
    }
}
