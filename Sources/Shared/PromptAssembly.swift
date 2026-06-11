import Foundation

/// Time-aware greeting headline shown on the empty landing screen. Pure so the
/// "name from Settings appears in the welcome" flow is unit-testable.
public enum Greeting {
    public static func headline(userName: String, hour: Int) -> String {
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<17: salutation = "Good afternoon"
        case 17..<22: salutation = "Good evening"
        default: salutation = "Working late"
        }
        let name = userName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "\(salutation)!" : "\(salutation), \(name)!"
    }
}

/// Assembles the system prompt sent to the model from the active preset, the
/// preferred language, personality, the user's custom instructions, and any
/// compacted-context summary. Pure so the "custom instruction is injected"
/// flow is unit-testable without the view model.
public enum SystemPromptBuilder {
    public static func assemble(
        base: String,
        preferredLanguage: String,
        personalityPrompt: String?,
        customInstructions: String,
        contextSummary: String?
    ) -> String {
        var s = base
        s += " All responses must be in \(preferredLanguage)."
        if let p = personalityPrompt, !p.isEmpty {
            s += " " + p
        }
        let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            s += "\nUser instructions: \(custom)"
        }
        if let summary = contextSummary, !summary.isEmpty {
            s += "\n[Earlier conversation context] \(summary)"
        }
        return s
    }
}
