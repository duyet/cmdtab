import Foundation

/// Uniform inference surface shared by the cloud (AnyRouter) and on-device
/// (Foundation Models) backends. Both produce an `AsyncThrowingStream<String, Error>`
/// of **incremental text deltas** so `MainViewModel` can append chunks identically
/// regardless of which backend is active. Cancellation propagates through the
/// returned stream's terminating task (see each adapter).
public protocol InferenceAdapter: Sendable {
    /// Stable identifier for the backend (e.g. "anyrouter", "local").
    var id: String { get }

    /// Human-readable backend name for status display.
    var displayName: String { get }

    /// Whether the backend is ready to serve a request right now.
    var isAvailable: Bool { get }

    /// Reason the backend can't serve a request, or `nil` when available.
    var unavailableReason: String? { get }

    /// Streams a completion as incremental text deltas.
    ///
    /// - Parameters:
    ///   - instructions: System instructions guiding behaviour.
    ///   - history: Ordered prior conversation turns (user/assistant), excluding
    ///     the placeholder assistant message being filled.
    /// - Returns: A delta stream; finishes when generation completes.
    func streamResponse(
        instructions: String,
        history: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error>
}

/// Cloud adapter: wraps the OpenAI-compatible SSE path in `APIClient` against AnyRouter.
public struct AnyRouterAdapter: InferenceAdapter {
    public let id = "anyrouter"
    public let displayName = "AnyRouter (Cloud)"

    private let endpointUrl: String
    private let apiKey: String
    private let model: String

    public init(endpointUrl: String, apiKey: String, model: String) {
        self.endpointUrl = endpointUrl
        self.apiKey = apiKey
        self.model = model
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
    ) async throws -> AsyncThrowingStream<String, Error> {
        let formatted = Self.formatMessages(
            instructions: instructions,
            history: history.map { (role: $0.role, content: $0.content) }
        )

        return try await APIClient.shared.fetchStream(
            endpointUrl: endpointUrl,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            model: model,
            messages: formatted
        )
    }
}

/// Local adapter: wraps `LocalModelClient` (Apple Foundation Models).
public struct LocalModelAdapter: InferenceAdapter {
    public let id = "local"
    public let displayName = "Local (Apple Intelligence)"

    public init() {}

    public var isAvailable: Bool { LocalModelClient.shared.availability.isAvailable }

    public var unavailableReason: String? {
        LocalModelClient.shared.availability.unavailableReason
    }

    public func streamResponse(
        instructions: String,
        history: [ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Error> {
        // Foundation Models is single-turn here: use the latest user prompt.
        let prompt = history.last(where: { $0.role == "user" })?.content ?? ""
        return try LocalModelClient.shared.streamResponse(
            instructions: instructions,
            prompt: prompt
        )
    }
}
