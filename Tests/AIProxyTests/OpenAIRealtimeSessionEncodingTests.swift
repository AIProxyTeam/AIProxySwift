//
//  OpenAIRealtimeSessionEncodingTests.swift
//  AIProxyTests
//

import Foundation
import Testing
@testable import AIProxy

/// Encoding contract tests for Realtime client payloads (`session.update`, `response.create`, `conversation.item.create`).
struct OpenAIRealtimeSessionEncodingTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = []
        return e
    }()

    @AIProxyActor
    private func compilePerformanceRealtimeSessionCall(
        service: OpenAIService
    ) async throws {
        _ = try await service.realtimeSession(
            model: "gpt-realtime-1.5",
            configuration: .init(),
            logLevel: .debug
        )
    }

    @Test
    func sessionUpdateEncodesNestedAudioAndOutputModalities() throws {
        let update = OpenAIRealtimeSessionUpdate(
            session: OpenAIRealtimeSessionConfiguration(
                type: .realtime,
                inputAudioFormat: .pcm16,
                instructions: "Hi",
                maxOutputTokens: .int(100),
                outputModalities: [.audio],
                outputAudioFormat: .pcm16
            )
        )
        let encoded = try encoder.encode(update)
        let root = try Self.jsonObject(encoded) as! [String: Any]
        #expect(root["type"] as? String == "session.update")
        let session = root["session"] as! [String: Any]
        #expect(session["type"] as? String == "realtime")
        #expect(session["instructions"] as? String == "Hi")
        #expect(session["max_output_tokens"] as? Int == 100)
        #expect(session["output_modalities"] as? [String] == ["audio"])
        #expect(session["modalities"] == nil)
        #expect(session["max_response_output_tokens"] == nil)
        #expect(session["reasoning"] == nil)
        #expect(session["parallel_tool_calls"] == nil)
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let inputFormat = input["format"] as! [String: Any]
        #expect(inputFormat["type"] as? String == "audio/pcm")
        #expect(inputFormat["rate"] as? Int == 24000)
    }

    @Test
    func sessionUpdateAcceptsInlineDefaultPerformanceConfiguration() throws {
        let update = OpenAIRealtimeSessionUpdate(session: .init())
        let encoded = try encoder.encode(update)
        let root = try Self.jsonObject(encoded) as! [String: Any]
        let session = root["session"] as! [String: Any]

        #expect(session["type"] as? String == "realtime")
        #expect(session["reasoning"] == nil)
        #expect(session["parallel_tool_calls"] == nil)
    }

    @Test
    func reasoningSessionUpdateMergesBaseAndReasoningFields() throws {
        let update = OpenAIRealtimeSessionUpdate(
            session: OpenAIRealtimeSessionConfiguration(
                inputAudioFormat: .pcm16,
                instructions: "Solve carefully.",
                outputModalities: [.audio],
                voice: .builtin("alloy"),
                reasoning: .low,
                parallelToolCalls: true
            )
        )
        let encoded = try encoder.encode(update)
        let root = try Self.jsonObject(encoded) as! [String: Any]
        #expect(root["type"] as? String == "session.update")
        let session = root["session"] as! [String: Any]
        #expect(session["instructions"] as? String == "Solve carefully.")
        #expect(session["output_modalities"] as? [String] == ["audio"])
        #expect(session["parallel_tool_calls"] as? Bool == true)
        let reasoning = session["reasoning"] as! [String: Any]
        #expect(reasoning["effort"] as? String == "low")
        let audio = session["audio"] as! [String: Any]
        let inputFormat = (audio["input"] as! [String: Any])["format"] as! [String: Any]
        #expect(inputFormat["type"] as? String == "audio/pcm")
        let output = audio["output"] as! [String: Any]
        #expect(output["voice"] as? String == "alloy")
    }

    @Test
    func sessionUpdateEncodesG711AudioFormatObjects() throws {
        let update = OpenAIRealtimeSessionUpdate(
            session: OpenAIRealtimeSessionConfiguration(
                inputAudioFormat: .g711Ulaw,
                outputAudioFormat: .g711Alaw
            )
        )
        let encoded = try encoder.encode(update)
        let session = (try Self.jsonObject(encoded) as! [String: Any])["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let inputFormat = (audio["input"] as! [String: Any])["format"] as! [String: Any]
        let outputFormat = (audio["output"] as! [String: Any])["format"] as! [String: Any]
        #expect(inputFormat["type"] as? String == "audio/pcmu")
        #expect(inputFormat["rate"] == nil)
        #expect(outputFormat["type"] as? String == "audio/pcma")
    }

    @Test
    func sessionUpdateEncodesInputAudioTranscriptionLogprobsInclude() throws {
        let update = OpenAIRealtimeSessionUpdate(
            session: OpenAIRealtimeSessionConfiguration(
                include: [.inputAudioTranscriptionLogprobs],
                inputAudioTranscription: .init(model: "gpt-4o-transcribe")
            )
        )
        let encoded = try encoder.encode(update)
        let session = (try Self.jsonObject(encoded) as! [String: Any])["session"] as! [String: Any]

        #expect(session["include"] as? [String] == ["item.input_audio_transcription.logprobs"])
    }

    @Test
    func serverVADTurnDetectionEncodesUnderAudioInput() throws {
        let update = OpenAIRealtimeSessionUpdate(
            session: OpenAIRealtimeSessionConfiguration(
                inputAudioFormat: .pcm16,
                turnDetection: .serverVAD(
                    .init(
                        createResponse: false,
                        idleTimeoutMs: 1500,
                        interruptResponse: true,
                        prefixPaddingMs: 250,
                        silenceDurationMs: 700,
                        threshold: 0.4
                    )
                )
            )
        )
        let encoded = try encoder.encode(update)
        let session = (try Self.jsonObject(encoded) as! [String: Any])["session"] as! [String: Any]
        let td = ((session["audio"] as! [String: Any])["input"] as! [String: Any])["turn_detection"] as! [String: Any]
        #expect(td["type"] as? String == "server_vad")
        #expect(td["create_response"] as? Bool == false)
        #expect(td["idle_timeout_ms"] as? Int == 1500)
        #expect(td["interrupt_response"] as? Bool == true)
        #expect(td["prefix_padding_ms"] as? Int == 250)
        #expect(td["silence_duration_ms"] as? Int == 700)
        #expect(td["threshold"] as? Double == 0.4)
    }

    @Test
    func voiceWithWebSearchHelperUsesBuiltinVoice() {
        let config = OpenAIRealtimeSessionConfiguration.voiceWithWebSearch()
        if case .builtin(let name)? = config.voice {
            #expect(name == "alloy")
        } else {
            Issue.record("Expected builtin alloy voice")
        }
        #expect(config.tools?.count == 1)
        #expect(config.toolChoice != nil)
    }

    @Test
    func conversationItemCreateUsesOutputTextForAssistantRole() throws {
        let item = OpenAIRealtimeConversationItemCreate.Item(role: "assistant", text: "Hello")
        let encoded = try Self.utf8JSONString(try encoder.encode(item))
        #expect(encoded.contains("\"type\":\"output_text\""))
        #expect(!encoded.contains("\"type\":\"text\""))
    }

    @Test
    func conversationItemCreateUsesInputTextForUserRole() throws {
        let item = OpenAIRealtimeConversationItemCreate.Item(role: "user", text: "Hello")
        let encoded = try Self.utf8JSONString(try encoder.encode(item))
        #expect(encoded.contains("\"type\":\"input_text\""))
    }

    @Test
    func responseCreateEncodesOutputModalitiesKey() throws {
        let event = OpenAIRealtimeResponseCreate(
            eventID: "evt_123",
            response: .init(
                instructions: "Be concise.",
                outputModalities: [.audio],
                tools: [.webSearch(.init(searchContextSize: .medium))],
                toolChoice: .auto
            )
        )
        let encoded = try encoder.encode(event)
        let root = try Self.jsonObject(encoded) as! [String: Any]
        #expect(root["type"] as? String == "response.create")
        let response = root["response"] as! [String: Any]
        #expect(response["instructions"] as? String == "Be concise.")
        #expect(response["output_modalities"] as? [String] == ["audio"])
        #expect(response["modalities"] == nil)
    }

    @Test
    func reasoningResponseCreateEncodesReasoning() throws {
        let event = OpenAIRealtimeResponseCreate(
            eventID: "evt_reasoning",
            response: .init(
                instructions: "Use the lowest sufficient reasoning effort.",
                outputModalities: [.audio],
                toolChoice: .auto,
                reasoning: .minimal,
                parallelToolCalls: false
            )
        )
        let encoded = try encoder.encode(event)
        let root = try Self.jsonObject(encoded) as! [String: Any]
        #expect(root["type"] as? String == "response.create")
        #expect(root["event_id"] as? String == "evt_reasoning")
        let response = root["response"] as! [String: Any]
        #expect(response["instructions"] as? String == "Use the lowest sufficient reasoning effort.")
        #expect(response["output_modalities"] as? [String] == ["audio"])
        #expect(response["tool_choice"] as? String == "auto")
        #expect(response["parallel_tool_calls"] as? Bool == false)
        let reasoning = response["reasoning"] as! [String: Any]
        #expect(reasoning["effort"] as? String == "minimal")
    }

    @Test(
        arguments: [nil, "minimal", "low", "medium", "high", "xhigh"] as [String?],
        [nil, false, true] as [Bool?]
    )
    func reasoningFieldsPreserveOptionalValuesAtBothScopes(
        effort: String?,
        parallelToolCalls: Bool?
    ) throws {
        let reasoning: OpenAIRealtimeReasoning?
        if let effort {
            let value: OpenAIRealtimeReasoning = try #require(
                OpenAIRealtimeReasoning(rawValue: effort)
            )
            reasoning = value
        } else {
            reasoning = nil
        }

        let update = OpenAIRealtimeSessionUpdate(
            session: .init(reasoning: reasoning, parallelToolCalls: parallelToolCalls)
        )
        let create = OpenAIRealtimeResponseCreate(
            response: .init(reasoning: reasoning, parallelToolCalls: parallelToolCalls)
        )
        let updateRoot = try #require(Self.jsonObject(encoder.encode(update)) as? [String: Any])
        let createRoot = try #require(Self.jsonObject(encoder.encode(create)) as? [String: Any])
        #expect(updateRoot["type"] as? String == "session.update")
        #expect(createRoot["type"] as? String == "response.create")

        let session = try #require(updateRoot["session"] as? [String: Any])
        let response = try #require(createRoot["response"] as? [String: Any])
        for payload in [session, response] {
            if let effort {
                let value = try #require(payload["reasoning"] as? [String: Any])
                #expect(value["effort"] as? String == effort)
                #expect(value.count == 1)
            } else {
                #expect(payload["reasoning"] == nil)
            }
            if let parallelToolCalls {
                #expect(payload["parallel_tool_calls"] as? Bool == parallelToolCalls)
            } else {
                #expect(payload["parallel_tool_calls"] == nil)
            }
            #expect(payload["parallelToolCalls"] == nil)
        }
        #expect(updateRoot["reasoning"] == nil)
        #expect(updateRoot["parallel_tool_calls"] == nil)
        #expect(createRoot["reasoning"] == nil)
        #expect(createRoot["parallel_tool_calls"] == nil)
    }

    @Test
    func responseCreateToolChoiceMCPEncodesObjectShape() throws {
        let event = OpenAIRealtimeResponseCreate(
            response: .init(
                outputModalities: [.text],
                toolChoice: .mcp(serverLabel: "acme_mcp", name: "lookup_ticket")
            )
        )
        let encoded = try encoder.encode(event)
        let response = (try Self.jsonObject(encoded) as! [String: Any])["response"] as! [String: Any]
        let tc = response["tool_choice"] as! [String: Any]
        #expect(tc["type"] as? String == "mcp")
        #expect(tc["server_label"] as? String == "acme_mcp")
        #expect(tc["name"] as? String == "lookup_ticket")
    }

    @Test
    func realtimeErrorWithObjectBodyDecodesMessage() throws {
        let payload = """
        {
          "type":"error",
          "event_id":"event_test",
          "error":{
            "type":"invalid_request_error",
            "code":"unknown_parameter",
            "message":"Unknown parameter: 'session.input_audio_format'."
          }
        }
        """
        let event = try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: Data(payload.utf8))
        guard case .error(let err) = event else {
            Issue.record("Expected error event")
            return
        }
        #expect(err.errorBody?.contains("Unknown parameter") == true)
    }

    private static func jsonObject(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [])
    }

    private static func utf8JSONString(_ data: Data) throws -> String {
        guard let s = String(data: data, encoding: .utf8) else {
            throw AIProxyError.assertion("UTF-8 JSON string decode failed")
        }
        return s
    }
}
