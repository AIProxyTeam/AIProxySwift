//  OpenAIBackgroundModelsTests.swift
//  AIProxy

import Foundation
import XCTest
import AIProxy

final class OpenAIBackgroundModelsTests: XCTestCase {

    func testOmittedBackgroundPreservesExistingRequestFields() throws {
        let request = OpenAICreateResponseRequestBody(
            input: .text("Describe a triangle."),
            model: "example-model",
            store: false,
            stream: true
        )

        XCTAssertNil(request.background)
        XCTAssertEqual(
            try encodedObject(request) as NSDictionary,
            [
                "input": "Describe a triangle.",
                "model": "example-model",
                "store": false,
                "stream": true
            ] as NSDictionary
        )
    }

    func testAllExplicitBackgroundAndStoreChoicesAreEncodedIndependently() throws {
        for background in [false, true] {
            for store in [nil, false, true] as [Bool?] {
                let request = OpenAICreateResponseRequestBody(
                    background: background,
                    model: "example-model",
                    store: store,
                    stream: false
                )
                let object = try encodedObject(request)

                XCTAssertEqual(request.background, background)
                XCTAssertEqual(request.store, store)
                XCTAssertEqual(object["background"] as? Bool, background)
                XCTAssertEqual(object["store"] as? Bool, store)
                XCTAssertEqual(object["stream"] as? Bool, false)
                XCTAssertEqual(object["model"] as? String, "example-model")
                XCTAssertEqual(object.count, store == nil ? 3 : 4)
            }
        }
    }

    func testExplicitNilBackgroundMatchesLegacyOmission() throws {
        let explicit = OpenAICreateResponseRequestBody(
            background: nil,
            input: .text("Describe a triangle."),
            model: "example-model"
        )
        let legacy = OpenAICreateResponseRequestBody(
            input: .text("Describe a triangle."),
            model: "example-model"
        )

        XCTAssertEqual(try encodedObject(explicit) as NSDictionary, try encodedObject(legacy) as NSDictionary)
        XCTAssertNil(try encodedObject(explicit)["background"])
        XCTAssertEqual(try encodedObject(OpenAICreateResponseRequestBody()).count, 0)
    }

    func testExistingInitializerCallPreservesAllSuppliedRequestFields() throws {
        let request = OpenAICreateResponseRequestBody(
            include: [.webSearchCallActionSources],
            input: .text("Describe a triangle."),
            instructions: "Answer briefly.",
            maxOutputTokens: 128,
            contextManagement: [.init(compactThreshold: 1000)],
            model: "example-model",
            parallelToolCalls: false,
            previousResponseId: "resp_previous",
            prompt: .init(id: "prompt_example"),
            reasoning: nil,
            safetyIdentifier: "example-safety-id",
            store: false,
            stream: true,
            temperature: 0.5,
            text: nil,
            toolChoice: .auto,
            tools: [],
            topP: 0.8,
            truncation: .disabled,
            user: "example-user"
        )

        let object = try encodedObject(request)
        XCTAssertNil(request.background)
        XCTAssertNil(object["background"])
        XCTAssertEqual(object["include"] as? [String], ["web_search_call.action.sources"])
        XCTAssertEqual(object["input"] as? String, "Describe a triangle.")
        XCTAssertEqual(object["instructions"] as? String, "Answer briefly.")
        XCTAssertEqual(object["max_output_tokens"] as? Int, 128)
        XCTAssertEqual(object["model"] as? String, "example-model")
        XCTAssertEqual(object["parallel_tool_calls"] as? Bool, false)
        XCTAssertEqual(object["previous_response_id"] as? String, "resp_previous")
        XCTAssertEqual(object["safety_identifier"] as? String, "example-safety-id")
        XCTAssertEqual(object["store"] as? Bool, false)
        XCTAssertEqual(object["stream"] as? Bool, true)
        XCTAssertEqual(object["temperature"] as? Double, 0.5)
        XCTAssertEqual(object["tool_choice"] as? String, "auto")
        XCTAssertEqual(object["top_p"] as? Double, 0.8)
        XCTAssertEqual(object["truncation"] as? String, "disabled")
        XCTAssertEqual(object["user"] as? String, "example-user")
        XCTAssertEqual((object["prompt"] as? [String: Any])?["id"] as? String, "prompt_example")
        XCTAssertEqual((object["context_management"] as? [[String: Any]])?.first?["compact_threshold"] as? Int, 1000)
        XCTAssertEqual((object["tools"] as? [Any])?.count, 0)
    }

    func testAllSixKnownStatusesDecodeWithoutChangingExistingRawValues() throws {
        let cases: [(String, OpenAIResponse.Status)] = [
            ("queued", .queued),
            ("in_progress", .inProgress),
            ("completed", .completed),
            ("failed", .failed),
            ("incomplete", .incomplete),
            ("cancelled", .cancelled)
        ]

        for (rawValue, expected) in cases {
            let response = try decodeResponse(#"{"id":"resp_example","status":"\#(rawValue)","output":[],"usage":null}"#)
            XCTAssertEqual(response.status, expected)
            XCTAssertEqual(expected.rawValue, rawValue)
            XCTAssertEqual(response.id, "resp_example")
            XCTAssertTrue(response.output.isEmpty)
            XCTAssertNil(response.usage)
            XCTAssertEqual(response.outputText, "")
        }
    }

    func testMissingOrNullStatusRemainsNil() throws {
        for json in [
            #"{"id":"resp_example","output":[]}"#,
            #"{"id":"resp_example","status":null,"output":[]}"#
        ] {
            let response = try decodeResponse(json)
            XCTAssertNil(response.status)
            XCTAssertTrue(response.output.isEmpty)
            XCTAssertEqual(response.outputText, "")
        }
    }

    func testUnsupportedStatusThrowsDecodingError() throws {
        XCTAssertThrowsError(try decodeResponse(#"{"status":"unsupported","output":[]}"#)) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected a data-corrupted decoding error, received \(error)")
            }
        }
    }

    func testQueuedSnapshotAndCreatedEventPreserveEarlyIdentity() throws {
        let json = #"{"id":"resp_example","status":"queued","output":[],"usage":null}"#
        let snapshot = try decodeResponse(json)
        let event = try decodeEvent(#"{"type":"response.created","sequence_number":7,"response":\#(json)}"#)

        XCTAssertEqual(snapshot.id, "resp_example")
        XCTAssertEqual(snapshot.status, .queued)
        XCTAssertTrue(snapshot.output.isEmpty)
        XCTAssertNil(snapshot.usage)

        guard case .responseCreated(let created) = event else {
            return XCTFail("Expected response.created")
        }
        XCTAssertEqual(created.sequenceNumber, 7)
        XCTAssertEqual(created.response.id, "resp_example")
        XCTAssertEqual(created.response.status, .queued)
        XCTAssertTrue(created.response.output.isEmpty)
        XCTAssertNil(created.response.usage)
    }

    func testResponseQueuedKeepsItsRawJSONPayloadAndSequence() throws {
        let event = try decodeEvent(
            #"{"type":"response.queued","sequence_number":8,"response":{"id":"resp_example","status":"queued","output":[],"future_field":"preserved"}}"#
        )

        guard case .responseQueued(let queued) = event else {
            return XCTFail("Expected response.queued")
        }
        let rawResponse: AIProxyJSONValue = queued.response
        guard case .object(let object) = rawResponse,
              case .string(let id) = object["id"],
              case .string(let status) = object["status"],
              case .array(let output) = object["output"],
              case .string(let futureField) = object["future_field"] else {
            return XCTFail("Expected the unchanged raw queue payload")
        }
        XCTAssertEqual(queued.sequenceNumber, 8)
        XCTAssertEqual(id, "resp_example")
        XCTAssertEqual(status, "queued")
        XCTAssertTrue(output.isEmpty)
        XCTAssertEqual(futureField, "preserved")
    }

    func testFailureAndIncompleteDetailsArePubliclyReadable() throws {
        let failed = try decodeResponse(
            #"{"id":"resp_example","status":"failed","output":[],"error":{"code":"server_error","message":"Generation failed."}}"#
        )
        let incomplete = try decodeResponse(
            #"{"id":"resp_example","status":"incomplete","output":[],"incomplete_details":{"reason":"max_output_tokens"}}"#
        )

        // This file imports the public module without @testable.
        let code: String? = failed.error?.code
        let message: String? = failed.error?.message
        let reason: String? = incomplete.incompleteDetails?.reason
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(code, "server_error")
        XCTAssertEqual(message, "Generation failed.")
        XCTAssertEqual(incomplete.status, .incomplete)
        XCTAssertEqual(reason, "max_output_tokens")
    }

    func testExistingNestedLifecycleEventsRetainStatusesAndSequence() throws {
        let progress = try decodeEvent(
            #"{"type":"response.in_progress","sequence_number":9,"response":{"id":"resp_example","status":"in_progress","output":[]}}"#
        )
        let failure = try decodeEvent(
            #"{"type":"response.failed","sequence_number":10,"response":{"id":"resp_example","status":"failed","output":[],"error":{"code":"server_error","message":"Generation failed."}}}"#
        )
        let incomplete = try decodeEvent(
            #"{"type":"response.incomplete","sequence_number":11,"response":{"id":"resp_example","status":"incomplete","output":[],"incomplete_details":{"reason":"max_output_tokens"}}}"#
        )

        guard case .responseInProgress(let inProgress) = progress,
              case .responseFailed(let failed) = failure,
              case .responseIncomplete(let unfinished) = incomplete else {
            return XCTFail("Expected the existing lifecycle event cases")
        }
        XCTAssertEqual(inProgress.sequenceNumber, 9)
        XCTAssertEqual(inProgress.response.status, .inProgress)
        XCTAssertEqual(failed.sequenceNumber, 10)
        XCTAssertEqual(failed.response.status, .failed)
        XCTAssertEqual(failed.response.error?.code, "server_error")
        XCTAssertEqual(failed.response.error?.message, "Generation failed.")
        XCTAssertEqual(unfinished.sequenceNumber, 11)
        XCTAssertEqual(unfinished.response.status, .incomplete)
        XCTAssertEqual(unfinished.response.incompleteDetails?.reason, "max_output_tokens")
    }

    func testCompletedOutputPreservesReasoningSourcesAnnotationsOrderAndUsage() throws {
        let response = try decodeResponse(Self.completedResponseJSON)
        XCTAssertEqual(response.status, .completed)
        XCTAssertEqual(response.output.count, 4)
        XCTAssertEqual(response.outputText, "First.Second.")

        guard case .reasoning(let reasoning) = response.output[0],
              case .webSearchCall(let search) = response.output[1],
              case .message(let firstMessage) = response.output[2],
              case .message(let secondMessage) = response.output[3],
              case .outputText(let firstText) = firstMessage.content[0],
              case .urlCitation(let citation) = firstText.annotations?.first else {
            return XCTFail("Expected supported output items in fixture order")
        }
        XCTAssertEqual(reasoning.id, "rs_example")
        XCTAssertEqual(reasoning.summary?.first?.text, "Checked the sources.")
        XCTAssertEqual(search.id, "ws_example")
        XCTAssertEqual(search.action?.query, "triangle")
        XCTAssertEqual(search.action?.sources?.first?.type, "url")
        XCTAssertEqual(search.action?.sources?.first?.url, "https://example.com/source")
        XCTAssertEqual(firstMessage.id, "msg_first")
        XCTAssertEqual(secondMessage.id, "msg_second")
        XCTAssertEqual(firstText.text, "First.")
        XCTAssertEqual(citation.startIndex, 0)
        XCTAssertEqual(citation.endIndex, 5)
        XCTAssertEqual(citation.title, "Example source")
        XCTAssertEqual(citation.url.absoluteString, "https://example.com/source")
        XCTAssertEqual(response.usage?.inputTokens, 100)
        XCTAssertEqual(response.usage?.inputTokensDetails?.cachedTokens, 20)
        XCTAssertEqual(response.usage?.outputTokens, 40)
        XCTAssertEqual(response.usage?.outputTokensDetails?.reasoningTokens, 10)
        XCTAssertEqual(response.usage?.totalTokens, 140)
    }

    func testRefusalExplanationIsDecodedForSnapshotAndNestedCompletedEvent() throws {
        let snapshot = try decodeResponse(Self.completedResponseJSON)
        let event = try decodeEvent(
            #"{"type":"response.completed","sequence_number":12,"response":\#(Self.completedResponseJSON)}"#
        )
        guard case .responseCompleted(let completed) = event else {
            return XCTFail("Expected response.completed")
        }
        XCTAssertEqual(completed.sequenceNumber, 12)
        XCTAssertEqual(completed.response.id, "resp_example")
        XCTAssertEqual(completed.response.status, .completed)

        for response in [snapshot, completed.response] {
            guard case .message(let message) = response.output[3],
                  case .refusal(let explanation) = message.content[0] else {
                return XCTFail("Expected refusal content")
            }
            XCTAssertEqual(explanation, "I cannot provide that content.")
            XCTAssertEqual(response.outputText, "First.Second.")
        }
    }

    private func encodedObject(_ request: OpenAICreateResponseRequestBody) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decodeResponse(_ json: String) throws -> OpenAIResponse {
        try JSONDecoder().decode(OpenAIResponse.self, from: Data(json.utf8))
    }

    private func decodeEvent(_ json: String) throws -> OpenAIResponseStreamingEvent {
        try JSONDecoder().decode(OpenAIResponseStreamingEvent.self, from: Data(json.utf8))
    }

    private static let completedResponseJSON = #"""
    {
      "id": "resp_example",
      "status": "completed",
      "output": [
        {
          "type": "reasoning",
          "id": "rs_example",
          "summary": [{"type": "summary_text", "text": "Checked the sources."}]
        },
        {
          "type": "web_search_call",
          "id": "ws_example",
          "status": "completed",
          "action": {
            "type": "search",
            "query": "triangle",
            "sources": [{"type": "url", "url": "https://example.com/source"}]
          }
        },
        {
          "type": "message",
          "id": "msg_first",
          "role": "assistant",
          "status": "completed",
          "content": [
            {
              "type": "output_text",
              "text": "First.",
              "annotations": [
                {
                  "type": "url_citation",
                  "start_index": 0,
                  "end_index": 5,
                  "url": "https://example.com/source",
                  "title": "Example source"
                }
              ]
            }
          ]
        },
        {
          "type": "message",
          "id": "msg_second",
          "role": "assistant",
          "status": "completed",
          "content": [
            {"type": "refusal", "refusal": "I cannot provide that content."},
            {"type": "output_text", "text": "Second.", "annotations": []}
          ]
        }
      ],
      "usage": {
        "input_tokens": 100,
        "input_tokens_details": {"cached_tokens": 20},
        "output_tokens": 40,
        "output_tokens_details": {"reasoning_tokens": 10},
        "total_tokens": 140
      }
    }
    """#
}
