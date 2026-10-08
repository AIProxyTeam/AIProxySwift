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

/// An HTTP failure returned by OpenAI response retrieval.
/// Header field names should be compared case-insensitively.
nonisolated public struct AIProxyHTTPError: Error, Sendable {
    public let statusCode: Int
    public let responseBody: String
    public let headers: [String: String]

    public init(statusCode: Int, responseBody: String, headers: [String: String]) {
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.headers = headers
    }
}
