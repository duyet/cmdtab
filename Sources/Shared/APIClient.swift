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
    /// A line with no actionable payload (blank line, comment, usage-only
    /// chunk with empty `choices`, or a non-`data:` field). Skip and continue.
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

        // Usage-only chunk (stream_options.include_usage) has empty `choices`.
        if let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let delta = firstChoice["delta"] as? [String: Any],
            let content = delta["content"] as? String
        {
            return .delta(content)
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
        messages: [[String: String]]
    ) -> [String: Any] {
        [
            "model": model,
            "messages": messages,
            "stream": true,
            "stream_options": ["include_usage": true],
        ]
    }

    /// Builds the fully-configured `URLRequest`, or throws if the URL or body is invalid.
    public static func makeRequest(
        endpointUrl: String,
        apiKey: String?,
        model: String,
        messages: [[String: String]]
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
        request.setValue("cmdtab", forHTTPHeaderField: "X-AnyRouter-App")
        request.setValue("https://github.com/duyet/cmdtab", forHTTPHeaderField: "X-AnyRouter-Referer")
        request.setValue("cmdtab", forHTTPHeaderField: "X-AnyRouter-Title")

        if let apiKey = apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard
            let httpBody = try? JSONSerialization.data(
                withJSONObject: requestBody(model: model, messages: messages),
                options: []
            )
        else {
            throw APIError.serializationError
        }
        request.httpBody = httpBody
        return request
    }
}

/// Stateless cloud client; holds no mutable state, so it is safe to share across
/// tasks. `Sendable` lets the singleton satisfy Swift 6 strict-concurrency checks.
public final class APIClient: Sendable {
    public static let shared = APIClient()

    private init() {}

    /// Streams chat completions using Server-Sent Events (SSE) with full conversation history.
    public func fetchStream(
        endpointUrl: String,
        apiKey: String?,
        model: String,
        messages: [[String: String]]
    ) async throws -> AsyncThrowingStream<String, Error> {

        let request = try AnyRouterRequestFactory.makeRequest(
            endpointUrl: endpointUrl,
            apiKey: apiKey,
            model: model,
            messages: messages
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
                            continuation.yield(content)
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
