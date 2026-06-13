import Foundation

public enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int, body: String)
    case serializationError
    case missingApiKey
    case streamError(message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API Endpoint URL."
        case .invalidResponse(let code, let body):
            let preview = String(body.prefix(200))
            return "Server returned error \(code): \(preview)"
        case .serializationError:
            return "Failed to serialize request payload."
        case .missingApiKey:
            return "API Key is required but not configured."
        case .streamError(let message):
            return message
        }
    }

    /// Concise message for chat display. Unlike `errorDescription` (which
    /// preserves the raw body for diagnostics), this extracts the provider's
    /// human-readable `error.message` from JSON bodies when present.
    public var userMessage: String {
        switch self {
        case .invalidResponse(let code, let body):
            if let data = body.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let error = object["error"] as? [String: Any],
                let message = error["message"] as? String
            {
                return "\(message) (HTTP \(code))"
            }
            return "The server returned an error (HTTP \(code))."
        default:
            return errorDescription ?? "Something went wrong."
        }
    }
}

// MARK: - SSE Parsing

/// Outcome of parsing a single Server-Sent Events line from the cloud stream.
///
/// SSE framing is line-oriented: each `data:` line carries one JSON chunk.
/// Splitting parsing into a pure function lets us unit-test every frame shape
/// (delta, usage-only, error, `[DONE]`, comments) without a live network socket.
public enum SSEEvent: Equatable {
    /// A `data:` frame carrying an incremental text delta to append.
    case delta(String)
    /// The terminal `data: [DONE]` sentinel; the stream is complete.
    case done
    /// A mid-stream error frame; generation must stop and surface `message`.
    case error(message: String)
    /// Usage metadata from the final chunk (token counts, model name).
    case usage(StreamUsage)
    /// A line with no actionable payload (blank line, comment, or a non-`data:` field).
    case ignore
}

/// Pure, network-free SSE frame parser for OpenAI-compatible completion streams.
public enum SSEParser {
    /// Parses one raw SSE line into an `SSEEvent`.
    ///
    /// Encodes the wire contract so consumers never re-implement it:
    /// - only `data:` fields carry payload; other fields/comments are ignored,
    /// - `[DONE]` terminates the stream,
    /// - an `error` object aborts with its message (default when absent),
    /// - a delta is yielded only when `choices[0].delta.content` is present,
    ///   so usage-only chunks (`stream_options.include_usage`) are ignored.
    public static func parseLine(_ rawLine: String) -> SSEEvent {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .ignore }
        guard trimmed.hasPrefix("data:") else { return .ignore }

        // Tolerate both "data: x" and "data:x" framing.
        let payload = String(trimmed.dropFirst("data:".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if payload == "[DONE]" { return .done }
        guard let data = payload.data(using: .utf8) else { return .ignore }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .ignore
        }

        // Error frame mid-stream: surface and stop.
        if let errObj = json["error"] as? [String: Any] {
            let message = (errObj["message"] as? String) ?? "Upstream provider error."
            return .error(message: message)
        }

        // Text delta from choices[0].delta.content.
        if let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let delta = firstChoice["delta"] as? [String: Any],
            let content = delta["content"] as? String
        {
            return .delta(content)
        }

        // Usage-only chunk (stream_options.include_usage) — extract token counts.
        if let usage = json["usage"] as? [String: Any] {
            let model = json["model"] as? String
            let promptTokens = usage["prompt_tokens"] as? Int
            let completionTokens = usage["completion_tokens"] as? Int
            // OpenAI nested detail: completion_tokens_details.reasoning_tokens
            var reasoningTokens: Int?
            if let details = usage["completion_tokens_details"] as? [String: Any] {
                reasoningTokens = details["reasoning_tokens"] as? Int
            }
            return .usage(StreamUsage(
                model: model,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                reasoningTokens: reasoningTokens
            ))
        }

        return .ignore
    }
}

// MARK: - Request Construction

/// Pure builder for the AnyRouter (OpenAI-compatible) chat-completions request.
///
/// Separated from `fetchStream` so URL normalization, app-attribution headers,
/// auth, and the streaming JSON body can be asserted without issuing a request.
public enum AnyRouterRequestFactory {
    /// Normalizes a base endpoint to a full `/chat/completions` URL string.
    ///
    /// AnyRouter callers configure a base URL (e.g. `https://anyrouter.dev/api/v1`);
    /// we append the completions path idempotently, tolerating a trailing slash and
    /// an already-complete URL so re-normalization is safe.
    public static func normalizedURLString(from endpointUrl: String) -> String {
        let base = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/chat/completions") { return base }
        return base.hasSuffix("/") ? base + "chat/completions" : base + "/chat/completions"
    }

    /// The streaming request body. `stream` is always `true` and usage is requested
    /// so the final chunk reports token counts; consumers ignore that usage-only frame.
    public static func requestBody(
        model: String,
        messages: [[String: String]],
        reasoningEffort: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
            "stream_options": ["include_usage": true],
        ]
        // Only sent for models that accept it (see ModelCatalog.supportsReasoning).
        if let reasoningEffort, !reasoningEffort.isEmpty {
            body["reasoning_effort"] = reasoningEffort
        }
        // Sampling controls — omitted when nil so providers keep their defaults.
        if let temperature {
            body["temperature"] = temperature
        }
        if let topP {
            body["top_p"] = topP
        }
        if let maxTokens, maxTokens > 0 {
            body["max_tokens"] = maxTokens
        }
        return body
    }

    /// Builds the fully-configured `URLRequest`, or throws if the URL or body is invalid.
    public static func makeRequest(
        endpointUrl: String,
        apiKey: String?,
        model: String,
        messages: [[String: String]],
        reasoningEffort: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: normalizedURLString(from: endpointUrl)) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // App attribution headers per the AnyRouter contract.
        request.setValue("https://minhagent.dev", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("MinhAgent", forHTTPHeaderField: "X-AnyRouter-Title")
        #if os(macOS)
        request.setValue("macos-app", forHTTPHeaderField: "X-AnyRouter-Source")
        #else
        request.setValue("ios-app", forHTTPHeaderField: "X-AnyRouter-Source")
        #endif
        request.setValue("1.0.0", forHTTPHeaderField: "X-AnyRouter-Version")
        request.setValue("general-chat,personal-agent", forHTTPHeaderField: "X-AnyRouter-Categories")

        if let apiKey = apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard
            let httpBody = try? JSONSerialization.data(
                withJSONObject: requestBody(
                    model: model, messages: messages, reasoningEffort: reasoningEffort,
                    temperature: temperature, topP: topP, maxTokens: maxTokens),
                options: []
            )
        else {
            throw APIError.serializationError
        }
        request.httpBody = httpBody
        return request
    }
}

// MARK: - AnyRouter Account + Model Catalog

public struct AnyRouterKeySummary: Equatable, Sendable {
    public let name: String
    public let prefix: String
    public let rateLimit: Int?
    public let usage: Int?
    public let isFreeTier: Bool

    public var displayText: String {
        let plan = isFreeTier ? "Free tier" : "Workspace"
        if let rateLimit {
            return "\(name) · \(plan) · \(rateLimit) rpm"
        }
        return "\(name) · \(plan)"
    }
}

public enum AnyRouterCatalogParser {
    public static func parseKeySummary(data: Data) throws -> AnyRouterKeySummary {
        let decoded = try JSONDecoder().decode(KeyResponse.self, from: data)
        return AnyRouterKeySummary(
            name: decoded.key.name,
            prefix: decoded.key.prefix,
            rateLimit: decoded.key.rateLimit,
            usage: decoded.key.usage,
            isFreeTier: decoded.key.isFreeTier
        )
    }

    public static func parseModels(data: Data) throws -> [ModelCatalog.Entry] {
        let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
        return decoded.data
            .filter { $0.category == nil || $0.category == "text" }
            .map { model in
                ModelCatalog.Entry(
                    id: model.id,
                    displayName: model.displayName,
                    sfSymbol: model.symbolName,
                    supportsReasoning: model.capabilities.contains { capability in
                        capability.lowercased().contains("reasoning")
                    },
                    inputPricePerMTok: model.pricing?.inputPer1M ?? model.pricing?.prompt.flatMap(Double.init),
                    outputPricePerMTok: model.pricing?.outputPer1M ?? model.pricing?.completion.flatMap(Double.init)
                )
            }
    }

    private struct KeyResponse: Decodable {
        let key: Key

        struct Key: Decodable {
            let prefix: String
            let name: String
            let rateLimit: Int?
            let usage: Int?
            let isFreeTier: Bool

            enum CodingKeys: String, CodingKey {
                case prefix
                case name
                case rateLimit = "rate_limit"
                case usage
                case isFreeTier = "is_free_tier"
            }
        }
    }

    private struct ModelsResponse: Decodable {
        let data: [RemoteModel]
    }

    private struct RemoteModel: Decodable {
        let id: String
        let provider: String?
        let category: String?
        let capabilities: [String]
        let pricing: Pricing?

        var displayName: String {
            let leaf = id.split(separator: "/").last.map(String.init) ?? id
            let words = leaf
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            let title = words
                .split(separator: " ")
                .map { part in
                    part.count <= 3 ? part.uppercased() : part.prefix(1).uppercased() + part.dropFirst()
                }
                .joined(separator: " ")
            if let provider, !provider.isEmpty {
                return "\(title) · \(provider)"
            }
            return title
        }

        var symbolName: String {
            if capabilities.contains(where: { $0.localizedCaseInsensitiveContains("vision") }) {
                return "eye"
            }
            if id.localizedCaseInsensitiveContains("gpt") || id.localizedCaseInsensitiveContains("claude") {
                return "brain"
            }
            if id.localizedCaseInsensitiveContains("flash") || id.localizedCaseInsensitiveContains("mini") {
                return "bolt"
            }
            return "sparkles"
        }
    }

    private struct Pricing: Decodable {
        let prompt: String?
        let completion: String?
        let inputPer1M: Double?
        let outputPer1M: Double?

        enum CodingKeys: String, CodingKey {
            case prompt
            case completion
            case inputPer1M = "input_per_1m"
            case outputPer1M = "output_per_1m"
        }
    }
}

/// Stateless cloud client; holds no mutable state, so it is safe to share across
/// tasks. `Sendable` lets the singleton satisfy Swift 6 strict-concurrency checks.
public final class APIClient: Sendable {
    public static let shared = APIClient()

    private init() {}

    public func inspectAnyRouterKey(endpointUrl: String, apiKey: String) async throws -> AnyRouterKeySummary {
        let base = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = base.hasSuffix("/") ? base + "auth/key" : base + "/auth/key"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: 0, body: "Non-HTTP response received")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
        }
        return try AnyRouterCatalogParser.parseKeySummary(data: data)
    }

    public func fetchAnyRouterModels(endpointUrl: String, apiKey: String) async throws -> [ModelCatalog.Entry] {
        let base = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = base.hasSuffix("/") ? base + "models?category=text" : base + "/models?category=text"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: 0, body: "Non-HTTP response received")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
        }
        return try AnyRouterCatalogParser.parseModels(data: data)
    }

    /// Streams chat completions using Server-Sent Events (SSE) with full conversation history.
    public func fetchStream(
        endpointUrl: String,
        apiKey: String?,
        model: String,
        messages: [[String: String]],
        reasoningEffort: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> AsyncThrowingStream<StreamChunk, Error> {

        let request = try AnyRouterRequestFactory.makeRequest(
            endpointUrl: endpointUrl,
            apiKey: apiKey,
            model: model,
            messages: messages,
            reasoningEffort: reasoningEffort,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens
        )

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: 0, body: "Non-HTTP response received")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorBody = ""
            do {
                for try await line in bytes.lines {
                    errorBody += line + "\n"
                    if errorBody.count > 10_000 { break }
                }
            } catch {}
            throw APIError.invalidResponse(statusCode: httpResponse.statusCode, body: errorBody)
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        switch SSEParser.parseLine(line) {
                        case .delta(let content):
                            continuation.yield(.delta(content))
                        case .usage(let usage):
                            continuation.yield(.usage(usage))
                        case .done:
                            continuation.finish()
                            return
                        case .error(let message):
                            continuation.finish(throwing: APIError.streamError(message: message))
                            return
                        case .ignore:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
