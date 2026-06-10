import Foundation

#if canImport(SwiftData)
import SwiftData
#endif

// MARK: - Persistence Models
// Parallel to the volatile Conversation/ChatMessage structs.
// MainViewModel maps between in-memory and persisted types on save/load.
// Using @Model classes gives us SwiftData + CloudKit sync for free.

#if canImport(SwiftData)

/// Persisted conversation, synced via CloudKit when configured.
@Model
final class PersistedConversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var timestamp: Date
    var presetId: UUID?

    /// Summarized context from older messages that were compacted out.
    /// nil when no compaction has occurred.
    var compactedSummary: String?

    @Relationship(deleteRule: .cascade, inverse: \PersistedMessage.conversation)
    var messages: [PersistedMessage] = []

    init(
        id: UUID = UUID(),
        title: String,
        timestamp: Date = Date(),
        presetId: UUID? = nil,
        compactedSummary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.presetId = presetId
        self.compactedSummary = compactedSummary
    }
}

/// Persisted message within a conversation.
@Model
final class PersistedMessage {
    @Attribute(.unique) var id: UUID
    var role: String  // "user" or "assistant"
    var content: String
    var timestamp: Date
    var isError: Bool

    var conversation: PersistedConversation?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isError = isError
    }
}

// MARK: - Mapping helpers

extension PersistedConversation {
    /// Create from a volatile in-memory Conversation.
    convenience init(from conversation: Conversation) {
        self.init(
            id: conversation.id,
            title: conversation.title,
            timestamp: conversation.timestamp,
            presetId: conversation.presetId,
            compactedSummary: conversation.compactedSummary
        )
        self.messages = conversation.messages.map { PersistedMessage(from: $0) }
        // Assign back-links after creating messages
        for msg in self.messages {
            msg.conversation = self
        }
    }

    /// Convert back to a volatile Conversation.
    func toVolatile() -> Conversation {
        Conversation(
            id: id,
            title: title,
            messages: messages.map { $0.toVolatile() },
            timestamp: timestamp,
            presetId: presetId,
            compactedSummary: compactedSummary
        )
    }
}

extension PersistedMessage {
    /// Create from a volatile in-memory ChatMessage.
    convenience init(from message: ChatMessage) {
        self.init(
            id: message.id,
            role: message.role,
            content: message.content,
            timestamp: message.timestamp,
            isError: message.isError
        )
    }

    /// Convert back to a volatile ChatMessage.
    func toVolatile() -> ChatMessage {
        ChatMessage(
            id: id,
            role: role,
            content: content,
            timestamp: timestamp,
            isError: isError
        )
    }
}

#endif
