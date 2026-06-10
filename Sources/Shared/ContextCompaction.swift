import Foundation

// MARK: - Token Estimation
/// Lightweight token estimator with no external dependencies.
/// ~4 chars/token for English/Latin, ~1.5 for CJK, +4 per-message overhead.
/// Good enough for compaction trigger decisions; not for exact billing.
public enum TokenEstimator {
    /// Rough token count for a single string.
    public static func estimate(_ text: String) -> Int {
        var latin = 0
        var cjk = 0
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // CJK Unified Ideographs, Hiragana, Katakana, Hangul
            if (0x4E00...0x9FFF).contains(v) || (0x3040...0x30FF).contains(v)
                || (0xAC00...0xD7AF).contains(v)
            {
                cjk += 1
            } else {
                latin += 1
            }
        }
        return (latin / 4) + (cjk / 2) + 4
    }

    /// Estimate total tokens across an array of messages.
    public static func estimate(messages: [ChatMessage]) -> Int {
        messages.reduce(0) { $0 + estimate($1.content) + 4 }
    }

    /// Compaction threshold for a given model.
    /// On-device FoundationModels has a 4,096 hard limit; cloud models vary.
    public static func compactThreshold(isLocal: Bool, modelId: String) -> Int {
        if isLocal { return 3_000 }
        if modelId.contains("gemma") || modelId.contains("mini") { return 100_000 }
        if modelId.contains("gpt-5") && !modelId.contains("mini") { return 200_000 }
        if modelId.contains("claude") { return 160_000 }
        if modelId.contains("gemini") { return 800_000 }
        return 100_000
    }
}

// MARK: - Compaction
extension MainViewModel {
    /// Number of recent messages to keep intact (not compacted).
    /// 6 messages = 3 full exchanges (user→assistant × 3).
    private static let recentWindow = 6

    /// Check if the active conversation needs compaction, and summarize
    /// older messages if so. Called before sending a new message.
    func compactIfNeeded() {
        guard let activeId = selectedConversationId,
            let activeIndex = conversations.firstIndex(where: { $0.id == activeId })
        else { return }

        let conversation = conversations[activeIndex]
        let messages = conversation.messages

        // Don't compact if we don't have enough messages to bother
        guard messages.count > Self.recentWindow else { return }

        let totalTokens = TokenEstimator.estimate(messages: messages)
        let threshold = TokenEstimator.compactThreshold(
            isLocal: isLocalModelSelected,
            modelId: modelName
        )

        guard totalTokens > threshold else { return }

        let splitIndex = messages.count - Self.recentWindow
        let oldMessages = Array(messages[..<splitIndex])
        let recentMessages = Array(messages[splitIndex...])

        // Build a simple inline summary rather than making an LLM call
        // (avoids recursive streaming during compaction).
        let summary = buildSummary(from: oldMessages, existing: conversation.compactedSummary)

        conversations[activeIndex].compactedSummary = summary
        conversations[activeIndex].messages = recentMessages
    }

    /// Build a compact text summary from old messages.
    /// For now, uses a lightweight truncation approach rather than LLM summarization
    /// to avoid recursive API calls. Can be upgraded to LLM-based summarization later.
    private func buildSummary(from messages: [ChatMessage], existing: String?) -> String {
        var parts: [String] = []

        if let existing = existing {
            parts.append("[Prior context] \(existing)")
        }

        // Take first 200 chars of each old message, capped at ~1500 chars total
        var budget = 1500
        for msg in messages {
            let prefix = "\(msg.role == "user" ? "User" : "Assistant"): "
            let content: String
            if msg.content.count > 200 {
                content = String(msg.content.prefix(200)) + "…"
            } else {
                content = msg.content
            }
            let entry = prefix + content
            if budget <= 0 { break }
            parts.append(entry)
            budget -= entry.count
        }

        return parts.joined(separator: "\n")
    }
}
