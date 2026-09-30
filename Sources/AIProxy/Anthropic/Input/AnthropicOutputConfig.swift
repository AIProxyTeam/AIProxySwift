//
//  AnthropicOutputConfig.swift
//  AIProxy
//
//  Created by Nick Bodmer on 9/29/26.
//

import Foundation

/// Output configuration for a message request (the `output_config` request field).
///
/// See [effort](https://docs.claude.com/en/docs/build-with-claude/effort) for details.
nonisolated public struct AnthropicOutputConfig: Encodable, Sendable {

    /// How much effort Claude spends on a response — thinking depth and overall token use.
    ///
    /// Supported on Claude 4.6 and later. The default is `high` on every current model except
    /// Opus 5.5, whose default is `medium`. `xhigh` and `max` require adaptive thinking; Sonnet 5.5
    /// rejects them together with `AnthropicThinkingConfigParam.betweenTools`.
    nonisolated public enum Effort: String, Encodable, Sendable {
        case low
        case medium
        case high
        case xhigh
        case max
    }

    public let effort: Effort?

    private enum CodingKeys: String, CodingKey {
        case effort
    }

    public init(effort: Effort? = nil) {
        self.effort = effort
    }
}
