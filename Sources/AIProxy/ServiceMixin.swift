//
//  ServiceMixin.swift
//  AIProxy
//
//  Created by Lou Zell on 4/24/25.
//

import Foundation

@AIProxyActor protocol ServiceMixin: Sendable {
    var urlSession: URLSession { get }
}

extension ServiceMixin {
    @AIProxyActor func makeRequestAndDeserializeResponse<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        let response: AIProxyResponseWithHeaders<T> = try await self.makeRequestAndDeserializeResponseWithMetadata(request)
        return response.body
    }

    @AIProxyActor func makeRequestAndDeserializeResponseWithMetadata<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AIProxyResponseWithHeaders<T> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }
        let (data, httpResponse) = try await BackgroundNetworker.makeRequestAndWaitForData(
            self.urlSession,
            request
        )
        if AIProxy.printResponseBodies {
            printBufferedResponseBody(data)
        }
        return AIProxyResponseWithHeaders(
            body: try T.deserialize(from: data),
            headers: httpResponse.readableHeaders
        )
    }

    /// OpenAI Responses requests preserve HTTP failure bytes and headers.
    @AIProxyActor func makeRequestAndDeserializeResponseWithHTTPMetadata<T: Decodable & Sendable>(
        _ request: URLRequest
    ) async throws -> AIProxyResponseWithHeaders<T> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }
        let session = self.urlSession
        let (data, response) = try await session.data(
            for: request,
            delegate: session.delegate as? URLSessionTaskDelegate
        )
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProxyError.assertion("Network response is not an http response")
        }
        if httpResponse.statusCode > 299 {
            logIf(.error)?.error("Receieved a non-200 status code: \(httpResponse.statusCode)")
            throw AIProxyHTTPError(
                statusCode: httpResponse.statusCode,
                responseData: data,
                headers: httpResponse.readableHeaders
            )
        }
        if AIProxy.printResponseBodies {
            printBufferedResponseBody(data)
        }
        return AIProxyResponseWithHeaders(
            body: try T.deserialize(from: data),
            headers: httpResponse.readableHeaders
        )
    }

    @AIProxyActor func makeRequestAndDeserializeStreamingChunks<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AsyncThrowingStream<T, Error> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }

        let (asyncBytes, _) = try await BackgroundNetworker.makeRequestAndWaitForAsyncBytes(
            self.urlSession,
            request
        )

        return self.decodeStreamingChunks(asyncBytes)
    }

    /// OpenAI Responses streaming establishment preserves HTTP failure bytes and headers.
    @AIProxyActor func makeRequestAndDeserializeStreamingChunksWithHTTPMetadata<T: Decodable & Sendable>(
        _ request: URLRequest
    ) async throws -> AsyncThrowingStream<T, Error> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }

        let session = self.urlSession
        let (asyncBytes, response) = try await session.bytes(
            for: request,
            delegate: session.delegate as? URLSessionTaskDelegate
        )
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProxyError.assertion("Network response is not an http response")
        }
        if httpResponse.statusCode > 299 {
            var responseData = Data()
            for try await byte in asyncBytes {
                responseData.append(byte)
            }
            throw AIProxyHTTPError(
                statusCode: httpResponse.statusCode,
                responseData: responseData,
                headers: httpResponse.readableHeaders
            )
        }
        return self.decodeStreamingChunks(asyncBytes)
    }

    @AIProxyActor private func decodeStreamingChunks<T: Decodable & Sendable>(
        _ asyncBytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<T, Error> {
        let sequence = asyncBytes.lines.compactMap { @AIProxyActor [shouldPrint = AIProxy.printResponseBodies] (line: String) -> T? in
            if shouldPrint {
                printStreamingResponseChunk(line)
            }
            return T.deserialize(fromLine: line)
        }

        // This swift juggling is because I don't want the return types of our API to be
        // something like: AsyncCompactMapSequence<AsyncLineSequence<URLSession.AsyncBytes>, OpenAIChatCompletionChunk>
        //
        // So instead I manually map it to an AsyncStream with a nice signature of AsyncThrowingStream<OpenAIChatCompletionChunk, Error>.
        return AsyncThrowingStream { @AIProxyActor continuation in
            let task = Task {
                do {
                    for try await item in sequence {
                        if Task.isCancelled {
                            break
                        }
                        continuation.yield(item)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Deserializes streaming NDJSON (newline-delimited JSON) chunks.
    /// Unlike `makeRequestAndDeserializeStreamingChunks`, this method does not expect
    /// SSE-style "data: " prefixes. Each line is treated as raw JSON.
    @AIProxyActor func makeRequestAndDeserializeNDJSONChunks<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AsyncThrowingStream<T, Error> {
        let response: AIProxyChunkStreamResponse<T> = try await self.makeRequestAndDeserializeNDJSONChunksWithMetadata(request)
        return response.stream
    }

    @AIProxyActor func makeRequestAndDeserializeNDJSONChunksWithMetadata<T: Decodable & Sendable>(_ request: URLRequest) async throws -> AIProxyChunkStreamResponse<T> {
        if AIProxy.printRequestBodies {
            printRequestBody(request)
        }

        let (asyncBytes, httpResponse) = try await BackgroundNetworker.makeRequestAndWaitForAsyncBytes(
            self.urlSession,
            request
        )

        let stream = AsyncThrowingStream<T, Error> { @AIProxyActor continuation in
            let task = Task {
                do {
                    for try await line in asyncBytes.lines {
                        if Task.isCancelled {
                            break
                        }
                        if AIProxy.printResponseBodies {
                            printStreamingResponseChunk(line)
                        }
                        guard !line.isEmpty else { continue }
                        guard let data = line.data(using: .utf8) else { continue }
                        do {
                            let deserialized = try T.deserialize(from: data)
                            continuation.yield(deserialized)
                        } catch {
                            logIf(.warning)?.warning(
                                """
                                AIProxy: Could not deserialize \(T.self) from NDJSON line: \(line)
                                Decodable error: \(error)
                                """
                            )
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
        return AIProxyChunkStreamResponse(
            headers: httpResponse.readableHeaders,
            stream: stream
        )
    }
}

private extension URLRequest {
    nonisolated var readableURL: String {
        return self.url?.absoluteString ?? ""
    }

    nonisolated var readableBody: String {
        guard let body = self.httpBody else {
            return "None"
        }

        return String(data: body, encoding: .utf8) ?? "None"
    }
}

nonisolated private func printRequestBody(_ request: URLRequest) {
    logIf(.debug)?.debug(
        """
        Making a request to \(request.readableURL)
        with request body:
        \(request.readableBody)
        """
    )
}

nonisolated private func printBufferedResponseBody(_ data: Data) {
    logIf(.debug)?.debug(
        """
        Received response body:
        \(String(data: data, encoding: .utf8) ?? "")
        """
    )
}

nonisolated private func printStreamingResponseChunk(_ chunk: String) {
    logIf(.debug)?.debug(
        """
        Received streaming response chunk:
        \(chunk)
        """
    )
}

extension HTTPURLResponse {
    var readableHeaders: [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in self.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        return headers
    }
}
