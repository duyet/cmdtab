import Foundation

/// A single conversation turn. Foundation-only (no SwiftUI) so the model layer and
/// the inference adapters that consume it remain unit-testable in the headless runner.
public struct ChatMessage: Codable, Identifiable, Equatable {
    public var id: UUID
    public var role: String  // "user" or "assistant"
    public var content: String
    public var timestamp: Date
    public var isError: Bool  // renders as an error card instead of markdown

    public init(
        id: UUID = UUID(), role: String, content: String, timestamp: Date = Date(), isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
    }
}

/// A volatile, in-memory conversation. Never persisted to disk (see AGENTS.md §1.1).
public struct Conversation: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var messages: [ChatMessage]
    public var timestamp: Date
    public var presetId: UUID?  // Links to Preset.id for system prompt lookup

    public init(
        id: UUID = UUID(), title: String, messages: [ChatMessage] = [], timestamp: Date = Date(), presetId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.timestamp = timestamp
        self.presetId = presetId
    }
}

/// A reusable system-prompt template applied to clipboard Quick Actions.
public struct Preset: Codable, Identifiable {
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
