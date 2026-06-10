import Foundation

#if !DISABLE_NATIVE_LLM
import FoundationModels
#endif

/// Availability of the on-device Apple Intelligence language model.
///
/// Mirrors `SystemLanguageModel.Availability` but adds `.compiledOut` for builds
/// produced with `-D DISABLE_NATIVE_LLM`, where the FoundationModels framework is
/// stubbed at compile time (see AGENTS.md §2.1).
public enum LocalModelAvailability: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    /// Built with `-D DISABLE_NATIVE_LLM`; on-device inference is unavailable.
    case compiledOut

    public var isAvailable: Bool { self == .available }

    /// User-facing reason the local model can't be used. `nil` when available.
    public var unavailableReason: String? {
        switch self {
        case .available:
            return nil
        case .deviceNotEligible:
            return "This device isn't eligible for Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence isn't enabled. Turn it on in System Settings."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        case .compiledOut:
            return "On-device model support isn't included in this build. Use the Cloud API."
        }
    }
}

/// Error surfaced when the on-device model can't fulfil a request.
public struct LocalModelError: Error, LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// Shared adapter for Apple's on-device FoundationModels inference.
///
/// Mirrors the consumption shape of `APIClient.fetchStream`: it returns an
/// `AsyncThrowingStream<String, Error>` that yields **incremental text deltas**,
/// so `MainViewModel` can append chunks with `+=` uniformly across cloud and
/// local backends. Cancellation propagates through the stream's task.
public final class LocalModelClient: Sendable {
    public static let shared = LocalModelClient()
    private init() {}

    /// Current availability of the on-device model.
    public var availability: LocalModelAvailability {
        #if DISABLE_NATIVE_LLM
        return .compiledOut
        #else
        guard #available(macOS 26.0, iOS 26.0, *) else {
            return .deviceNotEligible
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .modelNotReady
        }
        #endif
    }

    /// Streams an on-device completion for `prompt` as incremental text deltas.
    ///
    /// - Parameters:
    ///   - instructions: System instructions guiding model behaviour (priority over the prompt).
    ///   - prompt: The user prompt to respond to.
    /// - Returns: A stream yielding text deltas; finishes when generation completes.
    /// - Throws: `LocalModelError` if the model is unavailable.
    public func streamResponse(
        instructions: String,
        prompt: String
    ) throws -> AsyncThrowingStream<String, Error> {
        let availability = self.availability
        guard availability == .available else {
            throw LocalModelError(availability.unavailableReason ?? "On-device model is unavailable.")
        }

        #if DISABLE_NATIVE_LLM
        throw LocalModelError(LocalModelAvailability.compiledOut.unavailableReason!)
        #else
        guard #available(macOS 26.0, iOS 26.0, *) else {
            throw LocalModelError(LocalModelAvailability.deviceNotEligible.unavailableReason!)
        }
        let session = LanguageModelSession(instructions: instructions)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Plain-text streaming yields cumulative snapshots; convert to deltas
                    // so consumers can append uniformly with the cloud (SSE) path.
                    var emitted = ""
                    let stream = session.streamResponse(to: prompt)
                    for try await snapshot in stream {
                        guard !Task.isCancelled else { break }
                        let full = snapshot.content
                        if full.count > emitted.count, full.hasPrefix(emitted) {
                            continuation.yield(String(full.dropFirst(emitted.count)))
                            emitted = full
                        } else if full != emitted {
                            // Non-monotonic snapshot (rare); re-emit the full text.
                            continuation.yield(full)
                            emitted = full
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
        #endif
    }
}
