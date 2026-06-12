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
        userName: String,
        contextSummary: String?,
        currentDate: Date = Date()
    ) -> String {
        var parts: [String] = []
        
        // Base system prompt
        parts.append(base)
        
        // Language constraint
        parts.append("All responses must be in \(preferredLanguage).")
        
        // Personality prompt
        if let personality = personalityPrompt, !personality.isEmpty {
            parts.append(personality)
        }
        
        // Datetime injection — rounded to the hour to optimize prompt caching (prefix stability)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:00 a zzz"
        formatter.timeZone = TimeZone.current
        let dateStr = formatter.string(from: currentDate)
        parts.append("[Current Date & Time]\n\(dateStr)")
        
        // User information from settings
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            parts.append("[User Information]\nName: \(name)")
        }
        
        // Custom instructions from settings
        let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            parts.append("[Custom Instructions]\n\(custom)")
        }
        
        // Earlier context
        if let summary = contextSummary, !summary.isEmpty {
            parts.append("[Earlier Conversation Context]\n\(summary)")
        }
        
        return parts.joined(separator: "\n\n")
    }
}
