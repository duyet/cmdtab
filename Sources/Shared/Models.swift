import Foundation

/// Per-message inference metrics captured during streaming.
/// All fields optional for backward compatibility with persisted messages.
public struct InferenceMetrics: Codable, Equatable, Sendable {
    public var model: String?
    public var ttftMs: Int?           // time to first token (ms)
    public var totalMs: Int?          // total wall-clock generation time (ms)
    public var outputTokens: Int?
    public var inputTokens: Int?
    public var reasoningTokens: Int?

    public init(
        model: String? = nil,
        ttftMs: Int? = nil,
        totalMs: Int? = nil,
        outputTokens: Int? = nil,
        inputTokens: Int? = nil,
        reasoningTokens: Int? = nil
    ) {
        self.model = model
        self.ttftMs = ttftMs
        self.totalMs = totalMs
        self.outputTokens = outputTokens
        self.inputTokens = inputTokens
        self.reasoningTokens = reasoningTokens
    }

    /// Tokens per second, derived from outputTokens and totalMs.
    public var tps: Double? {
        guard let out = outputTokens, let total = totalMs, total > 0 else { return nil }
        return Double(out) / (Double(total) / 1000.0)
    }
}

/// A serialized transcript entry sent to the on-device LLM.
/// Persisted on `Conversation` so subsequent calls restore exact context
/// instead of rebuilding from `ChatMessage` objects (which can lose details).
public struct TranscriptEntryData: Codable, Equatable, Sendable {
    public var role: String      // "instructions", "user", "assistant"
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// A single conversation turn. Foundation-only (no SwiftUI) so the model layer and
/// the inference adapters that consume it remain unit-testable in the headless runner.
public struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var role: String  // "user" or "assistant"
    public var content: String
    public var timestamp: Date
    public var isError: Bool  // renders as an error card instead of markdown
    /// Quick Action that produced this turn, e.g. "Summarize". When set, the
    /// row shows a small action header. nil for ordinary typed messages.
    public var actionLabel: String?
    /// True when `content` is quoted clipboard text (renders with a quote bar).
    public var isQuote: Bool
    /// Inference metrics (TTFT, TPS, tokens, model) captured during streaming.
    public var inferenceMetrics: InferenceMetrics?

    public init(
        id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(),
        isError: Bool = false, actionLabel: String? = nil, isQuote: Bool = false,
        inferenceMetrics: InferenceMetrics? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
        self.actionLabel = actionLabel
        self.isQuote = isQuote
        self.inferenceMetrics = inferenceMetrics
    }

    // MARK: Codable — backward-compat with persisted data that has no inferenceMetrics key
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, isError, actionLabel, isQuote, inferenceMetrics
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(String.self, forKey: .role)
        content = try c.decode(String.self, forKey: .content)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        isError = try c.decode(Bool.self, forKey: .isError)
        actionLabel = try? c.decode(String.self, forKey: .actionLabel)
        isQuote = (try? c.decode(Bool.self, forKey: .isQuote)) ?? false
        inferenceMetrics = try? c.decode(InferenceMetrics.self, forKey: .inferenceMetrics)
    }
}

/// A conversation model. Persisted to disk inside the app's application support directory.
public struct Conversation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var messages: [ChatMessage]
    public var timestamp: Date
    public var presetId: UUID?  // Links to Preset.id for system prompt lookup

    /// Summarized context from older messages that were compacted out.
    /// nil when no compaction has occurred.
    public var compactedSummary: String?

    /// The raw request JSON of the latest request sent in this conversation.
    public var lastRawRequestDetails: String?

    /// Serialized transcript entries from the last on-device LLM call.
    /// Restored on the next call to preserve exact context without rebuilding.
    public var localTranscriptEntries: [TranscriptEntryData]?

    public init(
        id: UUID = UUID(), title: String, messages: [ChatMessage] = [], timestamp: Date = Date(), presetId: UUID? = nil,
        compactedSummary: String? = nil,
        lastRawRequestDetails: String? = nil,
        localTranscriptEntries: [TranscriptEntryData]? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.timestamp = timestamp
        self.presetId = presetId
        self.compactedSummary = compactedSummary
        self.lastRawRequestDetails = lastRawRequestDetails
        self.localTranscriptEntries = localTranscriptEntries
    }
}

/// A reusable system-prompt template applied to clipboard Quick Actions.
public struct Preset: Codable, Identifiable, Sendable {
    public static let iconChoices = [
        "sparkles", "bolt", "list.bullet", "globe", "lightbulb",
        "textformat.abc", "checklist", "pencil.and.scribble",
        "chevron.left.forwardslash.chevron.right", "doc.text",
        "envelope", "quote.bubble", "tag", "wand.and.rays",
    ]

    public var id: UUID
    public var name: String  // max 14 chars for card display
    public var sfSymbol: String  // SF Symbols name for the Quick Action card icon
    public var systemPrompt: String

    public init(id: UUID = UUID(), name: String, sfSymbol: String = "sparkles", systemPrompt: String) {
        self.id = id
        self.name = name
        self.sfSymbol = sfSymbol
        self.systemPrompt = systemPrompt
    }

    // MARK: Codable — backward-compat with persisted data that has no sfSymbol key
    enum CodingKeys: String, CodingKey {
        case id, name, sfSymbol, systemPrompt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        sfSymbol = (try? c.decode(String.self, forKey: .sfSymbol)) ?? "sparkles"
        systemPrompt = try c.decode(String.self, forKey: .systemPrompt)
    }
}
