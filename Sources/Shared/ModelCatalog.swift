import Foundation

/// Single source of truth for the AnyRouter cloud model list.
/// Both `ComposerView` (picker) and `SettingsView` (model section) reference this.
public enum ModelCatalog {
    public struct Entry: Identifiable, Sendable {
        public let id: String  // API model identifier
        public let displayName: String
        public let sfSymbol: String  // menu row icon

        public init(id: String, displayName: String, sfSymbol: String = "sparkles") {
            self.id = id
            self.displayName = displayName
            self.sfSymbol = sfSymbol
        }
    }

    /// Ordered model entries shown in pickers. Keep in sync with
    /// `MainViewModel.knownModelIds`. Icons: bolt = fast, brain = frontier,
    /// cube = open-weights, sparkles = balanced default.
    public static let entries: [Entry] = [
        Entry(id: "google/gemini-3.5-flash", displayName: "Gemini 3.5 Flash", sfSymbol: "bolt"),
        Entry(id: "google/gemma-4-26b-a4b-it", displayName: "Gemma 4 26B", sfSymbol: "cube"),
        Entry(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash", sfSymbol: "bolt"),
        Entry(id: "google/gemini-2.5-pro", displayName: "Gemini 2.5 Pro", sfSymbol: "brain"),
        Entry(id: "anthropic/claude-sonnet-4.6", displayName: "Claude Sonnet 4.6", sfSymbol: "sparkles"),
        Entry(id: "anthropic/claude-opus-4.2", displayName: "Claude Opus 4.2", sfSymbol: "brain"),
        Entry(id: "openai/gpt-5.4", displayName: "GPT-5.4", sfSymbol: "brain"),
        Entry(id: "openai/gpt-5.4-mini", displayName: "GPT-5.4 Mini", sfSymbol: "bolt"),
    ]
}
