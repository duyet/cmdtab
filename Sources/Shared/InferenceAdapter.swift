import Foundation

// MARK: - Stream Types

/// Element yielded by inference adapter streams.
/// Carries both incremental text and usage metadata through the same async stream.
public enum StreamChunk: Sendable, Equatable {
    /// Incremental text delta to append to the message.
    case delta(String)
    /// Usage metadata from the final stream chunk (cloud only).
    case usage(StreamUsage)
}

/// Token usage data reported by the cloud API in the final SSE chunk.
public struct StreamUsage: Codable, Equatable, Sendable {
    public var model: String?
    public var promptTokens: Int?
    public var completionTokens: Int?
    public var reasoningTokens: Int?

    public init(
        model: String? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        reasoningTokens: Int? = nil
    ) {
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.reasoningTokens = reasoningTokens
    }
}

// MARK: - Protocol

/// Uniform inference surface shared by the cloud (AnyRouter) and on-device
/// (Foundation Models) backends. Both produce an `AsyncThrowingStream<StreamChunk, Error>`
/// so `MainViewModel` can handle text deltas and usage data uniformly.
public protocol InferenceAdapter: Sendable {
    /// Stable identifier for the backend (e.g. "anyrouter", "local").
    var id: String { get }

    /// Human-readable backend name for status display.
    var displayName: String { get }

    /// Whether the backend is ready to serve a request right now.
    var isAvailable: Bool { get }

    /// Reason the backend can't serve a request, or `nil` when available.
    var unavailableReason: String? { get }

    /// Streams a completion as typed chunks (text deltas + usage metadata).
    func streamResponse(
        instructions: String,
        history: [ChatMessage]
    ) async throws -> AsyncThrowingStream<StreamChunk, Error>
}

// MARK: - Cloud Adapter

/// Cloud adapter: wraps the OpenAI-compatible SSE path in `APIClient` against AnyRouter.
public struct AnyRouterAdapter: InferenceAdapter {
    public let id = "anyrouter"
    public let displayName = "AnyRouter (Cloud)"

    private let endpointUrl: String
    private let apiKey: String
    private let model: String
    /// `reasoning_effort` to send, or nil when the model doesn't support it.
    private let reasoningEffort: String?
    private let temperature: Double?
    private let topP: Double?
    private let maxTokens: Int?

    public init(
        endpointUrl: String, apiKey: String, model: String, reasoningEffort: String? = nil,
        temperature: Double? = nil, topP: Double? = nil, maxTokens: Int? = nil
    ) {
        self.endpointUrl = endpointUrl
        self.apiKey = apiKey
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }

    public var isAvailable: Bool { !apiKey.isEmpty }

    public var unavailableReason: String? {
        isAvailable ? nil : "Add an AnyRouter API key in Settings to use the Cloud model."
    }

    /// Builds the OpenAI chat payload: a leading `system` turn carrying `instructions`,
    /// followed by the conversation history in order. Kept pure (role/content pairs,
    /// no `ChatMessage`) so the prompt assembly is unit-testable without view types.
    public static func formatMessages(
        instructions: String,
        history: [(role: String, content: String)]
    ) -> [[String: String]] {
        var formatted: [[String: String]] = [
            ["role": "system", "content": instructions]
        ]
        for msg in history {
            formatted.append(["role": msg.role, "content": msg.content])
        }
        return formatted
    }

    public func streamResponse(
        instructions: String,
        history: [ChatMessage]
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let formatted = Self.formatMessages(
            instructions: instructions,
            history: history.map { (role: $0.role, content: $0.content) }
        )

        return try await APIClient.shared.fetchStream(
            endpointUrl: endpointUrl,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model,
            messages: formatted,
            reasoningEffort: reasoningEffort,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens
        )
    }
}

// MARK: - Local Adapter

/// Local adapter: wraps `LocalModelClient` (Apple Foundation Models).
public struct LocalModelAdapter: InferenceAdapter {
    public let id = "local"
    public let displayName = "Local (Apple Intelligence)"

    private let enabledTools: Set<String>

    public init(enabledTools: Set<String> = []) {
        self.enabledTools = enabledTools
    }

    public var isAvailable: Bool { LocalModelClient.shared.availability.isAvailable }

    public var unavailableReason: String? {
        LocalModelClient.shared.availability.unavailableReason
    }

    // MARK: - InferenceAdapter conformance

    public func streamResponse(
        instructions: String,
        history: [ChatMessage]
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        try await streamResponse(instructions: instructions, history: history, transcriptEntries: nil)
    }

    /// Extended call with pre-serialized transcript entries for exact context restoration.
    public func streamResponse(
        instructions: String,
        history: [ChatMessage],
        transcriptEntries: [TranscriptEntryData]?
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {
        let prompt = history.last(where: { $0.role == "user" })?.content ?? ""
        // Use pre-serialized entries when available (preserves exact context),
        // otherwise build from ChatMessage history (first call in a conversation).
        let entries: [TranscriptEntryData]
        if let stored = transcriptEntries, !stored.isEmpty {
            entries = stored
        } else {
            entries = history.dropLast().map {
                TranscriptEntryData(role: $0.role, content: $0.content)
            }
        }
        // Wrap the string-based local stream into StreamChunk.delta values.
        let rawStream = try LocalModelClient.shared.streamResponse(
            instructions: instructions,
            prompt: prompt,
            transcriptEntries: entries,
            enabledTools: enabledTools
        )
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await text in rawStream {
                        continuation.yield(.delta(text))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }
}
