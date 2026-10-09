import Foundation

nonisolated public struct AIProxyResponseWithHeaders<Body: Sendable>: Sendable {
    public let body: Body
    public let headers: [String: String]

    public init(body: Body, headers: [String: String]) {
        self.body = body
        self.headers = headers
    }
}

nonisolated public struct AIProxyDataStreamResponse: Sendable {
    public let headers: [String: String]
    public let stream: AsyncStream<Data>

    public init(headers: [String: String], stream: AsyncStream<Data>) {
        self.headers = headers
        self.stream = stream
    }
}

nonisolated public struct AIProxyChunkStreamResponse<Chunk: Sendable>: Sendable {
    public let headers: [String: String]
    public let stream: AsyncThrowingStream<Chunk, Error>

    public init(headers: [String: String], stream: AsyncThrowingStream<Chunk, Error>) {
        self.headers = headers
        self.stream = stream
    }
}

/// An HTTP failure returned by any OpenAI REST operation, including requests that start a stream.
/// OpenAI REST callers previously catching `AIProxyError.unsuccessfulRequest` must catch this type instead.
/// Header field names should be compared case-insensitively.
nonisolated public struct AIProxyHTTPError: LocalizedError, Sendable {
    public let statusCode: Int
    /// The original HTTP response body bytes, including non-UTF-8 content.
    public let responseData: Data
    public let headers: [String: String]

    /// The response body decoded as UTF-8, or an empty string if decoding fails.
    public var responseBody: String {
        String(data: self.responseData, encoding: .utf8) ?? ""
    }

    public var errorDescription: String? {
        "AIProxy - the request resulted in a status code of \(self.statusCode) with response body: \(self.responseBody)."
    }

    public init(statusCode: Int, responseData: Data, headers: [String: String]) {
        self.statusCode = statusCode
        self.responseData = responseData
        self.headers = headers
    }
}
