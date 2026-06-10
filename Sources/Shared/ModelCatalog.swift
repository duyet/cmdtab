import Foundation

/// Single source of truth for the AnyRouter cloud model list.
/// Both `ComposerView` (picker) and `SettingsView` (model section) reference this.
public enum ModelCatalog {
    public struct Entry: Identifiable, Sendable {
        public let id: String  // API model identifier
        public let displayName: String

        public init(id: String, displayName: String) {
            self.id = id
            self.displayName = displayName
        }
    }

    /// Ordered model entries shown in pickers. Keep in sync with
    /// `MainViewModel.knownModelIds`.
    public static let entries: [Entry] = [
        Entry(id: "google/gemini-3.5-flash", displayName: "Gemini 3.5 Flash"),
        Entry(id: "google/gemma-4-26b-a4b-it", displayName: "Gemma 4 26B"),
        Entry(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash"),
        Entry(id: "google/gemini-2.5-pro", displayName: "Gemini 2.5 Pro"),
        Entry(id: "anthropic/claude-sonnet-4.6", displayName: "Claude Sonnet 4.6"),
        Entry(id: "anthropic/claude-opus-4.2", displayName: "Claude Opus 4.2"),
        Entry(id: "openai/gpt-5.4", displayName: "GPT-5.4"),
        Entry(id: "openai/gpt-5.4-mini", displayName: "GPT-5.4 Mini"),
    ]
}
