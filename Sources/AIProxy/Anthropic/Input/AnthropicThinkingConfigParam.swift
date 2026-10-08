//
//  AnthropicThinkingConfigParam.swift
//  AIProxy
//
//  Created by Lou Zell on 12/10/25.
//

import Foundation

/// Configuration for Claude's extended thinking.
///
/// When thinking is on, responses include `thinking` content blocks before the final answer, and
/// the thinking tokens count towards your `max_tokens` limit.
///
/// Which cases a model accepts depends on its generation:
/// - Claude 4.6 and later (Opus 4.6+, Sonnet 4.6+, Sonnet 5, Sonnet 5.5, Opus 5, Opus 5.5) use
///   `.adaptive`, with the depth controlled by `AnthropicMessageRequestBody.outputConfig` (effort).
///   These models reject `.enabled(budgetTokens:)`.
/// - Claude Sonnet 5.5 and Opus 5.5 reject `.disabled`. On Sonnet 5.5 the lowest setting is
///   `.betweenTools`; Opus 5.5 can't turn thinking off at all (lower the effort instead).
/// - Claude 4.5 and earlier (e.g. Haiku 4.5) use `.enabled(budgetTokens:)` or `.disabled`.
///
/// See [extended thinking](https://docs.claude.com/en/docs/build-with-claude/extended-thinking) for details.
nonisolated public enum AnthropicThinkingConfigParam: Encodable, Sendable {
    /// Enable extended thinking with a fixed token budget (Claude 4.5 and earlier).
    ///
    /// - Parameter budgetTokens: Determines how many tokens Claude can use for its internal
    ///   reasoning process. Larger budgets can enable more thorough analysis for complex problems,
    ///   improving response quality. Must be ≥1024 and less than `max_tokens`.
    case enabled(budgetTokens: Int)

    /// Adaptive thinking (Claude 4.6 and later): Claude decides when and how much to think.
    /// Control the depth with `AnthropicMessageRequestBody.outputConfig`.
    case adaptive

    /// The lowest thinking setting on Claude Sonnet 5.5, which rejects `.disabled`: no extended
    /// thinking, and only short progress notes between tool calls come back as `thinking` blocks.
    /// Accepted at effort `high` or below only, and by no other model.
    case betweenTools

    /// Disable extended thinking (not accepted by Claude Sonnet 5.5 or Opus 5.5).
    case disabled

    private enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .enabled(let budgetTokens):
            try container.encode("enabled", forKey: .type)
            try container.encode(budgetTokens, forKey: .budgetTokens)
        case .adaptive:
            try container.encode("adaptive", forKey: .type)
        case .betweenTools:
            try container.encode("between_tools", forKey: .type)
        case .disabled:
            try container.encode("disabled", forKey: .type)
        }
    }
}
