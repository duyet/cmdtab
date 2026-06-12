import Foundation

/// Single source of truth for the AnyRouter cloud model list.
/// Both `ComposerView` (picker) and `SettingsView` (model section) reference this.
public enum ModelCatalog {
    public struct Entry: Identifiable, Sendable {
        public let id: String  // API model identifier
        public let displayName: String
        public let sfSymbol: String  // menu row icon
        /// Whether the model accepts the OpenAI-compatible `reasoning_effort` param.
        public let supportsReasoning: Bool
        /// Cost per 1M input tokens in USD.
        public let inputPricePerMTok: Double?
        /// Cost per 1M output tokens in USD.
        public let outputPricePerMTok: Double?

        public init(
            id: String, displayName: String, sfSymbol: String = "sparkles",
            supportsReasoning: Bool = false,
            inputPricePerMTok: Double? = nil, outputPricePerMTok: Double? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.sfSymbol = sfSymbol
            self.supportsReasoning = supportsReasoning
            self.inputPricePerMTok = inputPricePerMTok
            self.outputPricePerMTok = outputPricePerMTok
        }

        /// Estimate cost in USD for given token counts.
        public func estimateCost(inputTokens: Int?, outputTokens: Int?) -> Double? {
            guard let inp = inputPricePerMTok, let out = outputPricePerMTok else { return nil }
            let inputCost = (inputTokens.map { Double($0) } ?? 0) * inp / 1_000_000
            let outputCost = (outputTokens.map { Double($0) } ?? 0) * out / 1_000_000
            let total = inputCost + outputCost
            return total > 0 ? total : nil
        }
    }

    /// Allowed `reasoning_effort` values, low → high.
    public static let reasoningEfforts: [String] = ["low", "medium", "high"]

    /// True when the given model id accepts a `reasoning_effort` parameter.
    public static func supportsReasoning(_ id: String) -> Bool {
        entries.first(where: { $0.id == id })?.supportsReasoning ?? false
    }

    /// Look up a model entry by its API id.
    public static func entry(for id: String) -> Entry? {
        entries.first(where: { $0.id == id })
    }

    /// Ordered model entries shown in pickers. Keep in sync with
    /// `MainViewModel.knownModelIds`. Icons: bolt = fast, brain = frontier,
    /// cube = open-weights, sparkles = balanced default.
    /// Pricing: approximate USD per 1M tokens (input / output).
    public static let entries: [Entry] = [
        Entry(id: "google/gemini-3.5-flash", displayName: "Gemini 3.5 Flash", sfSymbol: "bolt",
              inputPricePerMTok: 0.10, outputPricePerMTok: 0.40),
        Entry(id: "google/gemma-4-26b-a4b-it", displayName: "Gemma 4 26B", sfSymbol: "cube",
              inputPricePerMTok: 0.15, outputPricePerMTok: 0.15),
        Entry(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash", sfSymbol: "bolt",
              inputPricePerMTok: 0.15, outputPricePerMTok: 0.60),
        Entry(id: "google/gemini-2.5-pro", displayName: "Gemini 2.5 Pro", sfSymbol: "brain",
              inputPricePerMTok: 1.25, outputPricePerMTok: 10.00),
        Entry(id: "anthropic/claude-sonnet-4.6", displayName: "Claude Sonnet 4.6", sfSymbol: "sparkles",
              inputPricePerMTok: 3.00, outputPricePerMTok: 15.00),
        Entry(id: "anthropic/claude-opus-4.2", displayName: "Claude Opus 4.2", sfSymbol: "brain",
              inputPricePerMTok: 15.00, outputPricePerMTok: 75.00),
        Entry(id: "openai/gpt-5.4", displayName: "GPT-5.4", sfSymbol: "brain", supportsReasoning: true,
              inputPricePerMTok: 10.00, outputPricePerMTok: 30.00),
        Entry(id: "openai/gpt-5.4-mini", displayName: "GPT-5.4 Mini", sfSymbol: "bolt",
              supportsReasoning: true, inputPricePerMTok: 1.50, outputPricePerMTok: 6.00),
    ]
}
