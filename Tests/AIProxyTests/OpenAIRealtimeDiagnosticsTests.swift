import Foundation
import Testing
import AIProxy

/// Literal server payloads assert the public diagnostics contract independently of
/// the SDK's encoders, so omitted or renamed provider fields cannot hide a regression.
struct OpenAIRealtimeDiagnosticsTests {
    @Test
    func providerErrorRetainsEveryFieldAndDistinctEventIDs() throws {
        let event = try decode(RealtimeTestFixtures.structuredError)
        guard case .error(let payload) = event else {
            Issue.record("Expected provider error")
            return
        }
        #expect(payload.eventID == "server_error_1")
        #expect(payload.error?.eventID == "client_command_1")
        #expect(payload.error?.message == "Unsupported parameter.")
        #expect(payload.error?.type == "invalid_request_error")
        #expect(payload.error?.code == "unknown_parameter")
        #expect(payload.error?.param == "session.unsupported")
    }

    @Test(arguments: [
        #"{"type":"error","error":{"message":"Missing values"}}"#,
        #"{"type":"error","event_id":null,"error":{"message":"Missing values","type":null,"code":null,"param":null,"event_id":null}}"#
    ])
    func providerErrorDoesNotInventOptionalEvidence(_ json: String) throws {
        guard case .error(let payload) = try decode(json) else {
            Issue.record("Expected provider error")
            return
        }
        #expect(payload.error?.message == "Missing values")
        #expect(payload.error?.type == nil)
        #expect(payload.error?.code == nil)
        #expect(payload.error?.param == nil)
        #expect(payload.error?.eventID == nil)
        #expect(payload.eventID == nil)
    }

    @Test
    func stringOnlyErrorBecomesMessageOnlyEvidence() throws {
        let json = #"{"type":"error","error":"Legacy error text"}"#
        guard case .error(let payload) = try decode(json) else {
            Issue.record("Expected provider error")
            return
        }
        #expect(payload.error?.message == "Legacy error text")
        #expect(payload.error?.type == nil)
        #expect(payload.error?.code == nil)
        #expect(payload.error?.param == nil)
        #expect(payload.error?.eventID == nil)
        #expect(payload.eventID == nil)
    }

    @Test(arguments: [
        #"{"type":"error"}"#,
        #"{"type":"error","error":null}"#
    ])
    func absentErrorObjectRemainsAbsent(_ json: String) throws {
        guard case .error(let payload) = try decode(json) else {
            Issue.record("Expected provider error")
            return
        }
        #expect(payload.error == nil)
    }

    @Test(arguments: ["failed", "incomplete", "cancelled"])
    func unfinishedResponseRetainsStatusDetails(_ status: String) throws {
        let json = """
        {"type":"response.done","response":{"id":"response_outcome","conversation_id":"conversation_outcome","status":"\(status)","status_details":{"type":"\(status)","reason":"supplied_reason","error":{"code":"supplied_code","type":"supplied_error_type"}}}}
        """
        guard case .responseDone(let payload) = try decode(json) else {
            Issue.record("Expected response outcome")
            return
        }
        #expect(payload.responseID == "response_outcome")
        #expect(payload.conversationID == "conversation_outcome")
        #expect(payload.status == status)
        #expect(payload.statusDetails?.type == status)
        #expect(payload.statusDetails?.reason == "supplied_reason")
        #expect(payload.statusDetails?.error?.code == "supplied_code")
        #expect(payload.statusDetails?.error?.type == "supplied_error_type")
    }

    @Test(arguments: RealtimeTestFixtures.outcomes)
    func providerShapedOutcomeDetailsRemainReadable(_ fixture: RealtimeOutcomeFixture) throws {
        guard case .responseDone(let payload) = try decode(fixture.json) else {
            Issue.record("Expected response outcome")
            return
        }
        #expect(payload.status == fixture.status)
        #expect(payload.statusDetails?.type == fixture.status)
        #expect(payload.statusDetails?.reason == fixture.reason)
        #expect(payload.statusDetails?.error?.code == fixture.errorCode)
        #expect(payload.statusDetails?.error?.type == fixture.errorType)
    }

    @Test(arguments: ["", ",\"status_details\":null"])
    func completedResponseRetainsUsageWithoutInventingDetails(_ details: String) throws {
        let json = """
        {"type":"response.done","response":{"id":"completed_response","conversation_id":"completed_conversation","status":"completed","usage":{"input_tokens":3,"output_tokens":5,"total_tokens":8}\(details)}}
        """
        guard case .responseDone(let payload) = try decode(json) else {
            Issue.record("Expected completed response")
            return
        }
        #expect(payload.responseID == "completed_response")
        #expect(payload.conversationID == "completed_conversation")
        #expect(payload.status == "completed")
        #expect(payload.statusDetails == nil)
        #expect(payload.usage?.inputTokens == 3)
        #expect(payload.usage?.outputTokens == 5)
        #expect(payload.usage?.totalTokens == 8)
    }

    @Test
    func unknownStatusDetailsStringsRemainReadable() throws {
        let json = #"{"type":"response.done","response":{"id":"response_new","status":"incomplete","status_details":{"type":"future_type","reason":"future_reason","error":{"code":"future_code","type":"future_error_type"}}}}"#
        guard case .responseDone(let payload) = try decode(json) else {
            Issue.record("Expected response outcome")
            return
        }
        #expect(payload.statusDetails?.type == "future_type")
        #expect(payload.statusDetails?.reason == "future_reason")
        #expect(payload.statusDetails?.error?.code == "future_code")
        #expect(payload.statusDetails?.error?.type == "future_error_type")
    }

    @Test(arguments: [
        #"{"type":"response.done","response":{"id":"response_empty","status":"failed","status_details":{}}}"#,
        #"{"type":"response.done","response":{"id":"response_empty","status":"failed","status_details":{"type":null,"reason":null,"error":null}}}"#
    ])
    func statusDetailsDoesNotInventOptionalEvidence(_ json: String) throws {
        guard case .responseDone(let payload) = try decode(json) else {
            Issue.record("Expected response outcome")
            return
        }
        let details = try #require(payload.statusDetails)
        #expect(details.type == nil)
        #expect(details.reason == nil)
        #expect(details.error == nil)
    }

    private func decode(_ json: String) throws -> OpenAIRealtimeMessage {
        try JSONDecoder().decode(OpenAIRealtimeMessage.self, from: Data(json.utf8))
    }
}

nonisolated enum RealtimeTestFixtures {
    static let structuredError = #"{"type":"error","event_id":"server_error_1","error":{"message":"Unsupported parameter.","type":"invalid_request_error","code":"unknown_parameter","param":"session.unsupported","event_id":"client_command_1"}}"#
    static let secondError = #"{"type":"error","event_id":"server_error_2","error":{"message":"Another rejected command.","code":"invalid_value"}}"#
    static let text = #"{"type":"response.output_text.delta","event_id":"text_event","response_id":"response_1","item_id":"item_1","output_index":0,"content_index":0,"delta":"Ready"}"#
    static let audio = #"{"type":"response.output_audio.delta","event_id":"audio_event","response_id":"response_1","delta":"AQID"}"#
    static let failedResponse = #"{"type":"response.done","response":{"id":"response_1","status":"failed","status_details":{"type":"failed","error":{"code":"server_error","type":"server_error"}}}}"#
    static let malformedKnownEvent = #"{"type":"response.output_text.delta","delta":123}"#
    static let outcomes: [RealtimeOutcomeFixture] = [
        .init(json: #"{"type":"response.done","response":{"id":"response_failed","status":"failed","status_details":{"type":"failed","error":{"code":"server_error","type":"server_error"}}}}"#, status: "failed", reason: nil, errorCode: "server_error", errorType: "server_error"),
        .init(json: #"{"type":"response.done","response":{"id":"response_limited","status":"incomplete","status_details":{"type":"incomplete","reason":"max_output_tokens"}}}"#, status: "incomplete", reason: "max_output_tokens", errorCode: nil, errorType: nil),
        .init(json: #"{"type":"response.done","response":{"id":"response_filtered","status":"incomplete","status_details":{"type":"incomplete","reason":"content_filter"}}}"#, status: "incomplete", reason: "content_filter", errorCode: nil, errorType: nil),
        .init(json: #"{"type":"response.done","response":{"id":"response_interrupted","status":"cancelled","status_details":{"type":"cancelled","reason":"turn_detected"}}}"#, status: "cancelled", reason: "turn_detected", errorCode: nil, errorType: nil),
        .init(json: #"{"type":"response.done","response":{"id":"response_cancelled","status":"cancelled","status_details":{"type":"cancelled","reason":"client_cancelled"}}}"#, status: "cancelled", reason: "client_cancelled", errorCode: nil, errorType: nil)
    ]
}

nonisolated struct RealtimeOutcomeFixture: Sendable {
    let json: String
    let status: String
    let reason: String?
    let errorCode: String?
    let errorType: String?
}
