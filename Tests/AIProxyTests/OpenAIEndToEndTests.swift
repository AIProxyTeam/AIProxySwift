//
//  OpenAIEndToEndTests.swift
//
//
//  Created by Lou Zell on 8/11/24.
//

import XCTest
@testable import AIProxy

#if false // Flip to true to turn on E2E tests against a local host

final class OpenAIEndToEndTests: XCTestCase {

    func testBadPartialKeyReturnsBadStatusCode() async {
        let service = AIProxy.openAIService(
            partialKey: "v2|bad",
            serviceURL: "http://localhost:4000/24f38678/75624505"
        )

        let body = OpenAIChatCompletionRequestBody(
            model: "gpt-4o",
            messages: [.init(role: "system", content: .text("hello world"))]
        )

        do {
            _ = try await service.chatCompletionRequest(body: body)
            XCTFail("We expected a raised error")
        } catch let error as AIProxyHTTPError {
            XCTAssertEqual(
                #"{"error":{"message":"Could not infer required project properties from your requests"}}"#,
                error.responseBody
            )
            XCTAssertEqual(400, error.statusCode)
        } catch {
            XCTFail("We expected an AIProxyHTTPError")
        }
    }

    func testE2EChatCompletionBasic() async throws {
        let service = AIProxy.openAIService(
            partialKey: "v2|85dbd66f|WmQev4jb2Z4ElbWM",
            serviceURL: "http://localhost:4000/24f38678/75624505"
        )
        let body = OpenAIChatCompletionRequestBody(
            model: "gpt-4o",
            messages: [.init(role: "system", content: .text("hello world"))]
        )

        let response = try await service.chatCompletionRequest(body: body)
        XCTAssertEqual("gpt-4o-2024-05-13", response.model)
    }

    func testE2EChatCompletionWithImage() async throws {
        let service = AIProxy.openAIService(
            partialKey: "v2|85dbd66f|WmQev4jb2Z4ElbWM",
            serviceURL: "http://localhost:4000/24f38678/75624505"
        )

        let image = createImage(width: 10, height: 10)
        let localURL = AIProxy.openAIEncodedImage(image: image)!

        let body = OpenAIChatCompletionRequestBody(
            model: "gpt-4o",
            messages: [
                .init(
                    role: "system",
                    content: .text("Tell me what you see")
                ),
                .init(
                    role: "user",
                    content: .parts(
                        [
                            .text("What do you see?"),
                            .imageURL(localURL)
                        ]
                    )
                )
            ]
        )

        let response = try await service.chatCompletionRequest(body: body)
        XCTAssertEqual("gpt-4o-2024-05-13", response.model)

        // ChatGPT should see a red square:
        XCTAssertTrue(response.choices.first!.message.content.contains("red"))
    }
}

#endif
