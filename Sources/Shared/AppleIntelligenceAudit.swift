import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// One actionable item in the Apple Intelligence readiness audit.
///
/// The audit turns the coarse `LocalModelAvailability` state — plus a runtime
/// language check — into specific, one-click-fixable guidance shown in the UI.
public struct AIAuditFinding: Identifiable, Equatable {
    public enum Status: Equatable { case ok, warning, blocked }

    /// A System Settings destination the user can open in one click to fix this finding.
    public enum Fix: Equatable {
        case appleIntelligenceSettings   // Apple Intelligence & Siri pane
        case languageSettings            // Language & Region pane
    }

    public let id: String
    public let status: Status
    public let title: String
    public let detail: String
    public let fix: Fix?

    public init(id: String, status: Status, title: String, detail: String, fix: Fix?) {
        self.id = id
        self.status = status
        self.title = title
        self.detail = detail
        self.fix = fix
    }
}

/// Diagnoses why Apple Intelligence / the on-device model is (un)available and
/// produces ordered, actionable findings.
///
/// `LocalModelClient.shared.availability` (FoundationModels) is the authoritative
/// gate for whether on-device inference works. The language check is a *hint* only:
/// FoundationModels reports `appleIntelligenceNotEnabled` without naming the cause,
/// and the most common silent cause is a primary language / region that Apple
/// Intelligence doesn't support (e.g. "English (Vietnam)"). We surface that as a
/// likely cause — never as a hard claim.
public enum AppleIntelligenceAudit {
    /// Conservative allowlist of Apple Intelligence-supported primary language
    /// identifiers (`language-REGION`). Used only to *hint* at an unsupported
    /// regional variant when on-device inference is unavailable.
    static let supportedLanguageIDs: Set<String> = [
        "en-US", "en-GB", "en-AU", "en-CA", "en-IE", "en-NZ", "en-ZA", "en-IN", "en-SG",
        "fr-FR", "fr-CA", "de-DE", "it-IT", "es-ES", "es-US", "es-MX",
        "pt-BR", "pt-PT", "ja-JP", "ko-KR", "zh-CN", "zh-TW",
        "da-DK", "nl-NL", "nb-NO", "sv-SE", "tr-TR"
    ]

    /// Base languages Apple Intelligence supports in at least one region. Used to
    /// distinguish "wholly unsupported language" from "supported language, unusual region".
    static let supportedBaseLanguages: Set<String> = [
        "en", "fr", "de", "it", "es", "pt", "ja", "ko", "zh", "da", "nl", "nb", "no", "sv", "tr"
    ]

    /// The Mac's current primary language identifier, e.g. `"en-VN"`.
    public static var primaryLanguageID: String {
        Locale.preferredLanguages.first ?? Locale.current.identifier
    }

    /// Human-readable name for the primary language, e.g. `"English (Vietnam)"`.
    public static var primaryLanguageDisplayName: String {
        let id = primaryLanguageID
        return Locale.current.localizedString(forIdentifier: id) ?? id
    }

    /// Split an identifier like `"zh-Hans-CN"` / `"en_US"` into base + `base-REGION`.
    static func normalize(_ id: String) -> (base: String, regional: String) {
        let comps = id.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-").map(String.init)
        let base = comps.first?.lowercased() ?? id.lowercased()
        let region = comps.dropFirst().first(where: { $0.count == 2 })?.uppercased()
        let regional = region.map { "\(base)-\($0)" } ?? base
        return (base, regional)
    }

    /// True when the language looks supported. Conservative: only flags `false`
    /// for a clearly unsupported regional variant or a wholly unsupported language.
    static func languageIsLikelySupported(_ id: String) -> Bool {
        let (base, regional) = normalize(id)
        if supportedLanguageIDs.contains(regional) { return true }
        // Base supported but region not in the allowlist → likely an unsupported variant.
        if supportedBaseLanguages.contains(base) { return false }
        // Unknown base language → treat as unsupported (e.g. "vi").
        return false
    }

    /// Build the ordered findings for a given availability state.
    public static func findings(availability: LocalModelAvailability) -> [AIAuditFinding] {
        if availability == .compiledOut {
            return [AIAuditFinding(
                id: "build", status: .blocked,
                title: "On-device model not in this build",
                detail: "This build was compiled with on-device inference disabled. MinhAgent uses your cloud API instead.",
                fix: nil)]
        }

        if availability == .available {
            return [AIAuditFinding(
                id: "status", status: .ok,
                title: "Apple Intelligence is ready",
                detail: "The on-device model is available for local inference.",
                fix: nil)]
        }

        var out: [AIAuditFinding] = []

        switch availability {
        case .deviceNotEligible:
            out.append(AIAuditFinding(
                id: "device", status: .blocked,
                title: "This Mac isn't eligible",
                detail: "Apple Intelligence requires Apple Silicon (M1 or later). The system reports this device as not eligible, so on-device inference can't be enabled.",
                fix: nil))
        case .appleIntelligenceNotEnabled:
            out.append(AIAuditFinding(
                id: "enable", status: .blocked,
                title: "Apple Intelligence isn't turned on",
                detail: "Open Apple Intelligence & Siri and turn Apple Intelligence on. If the toggle is missing, the cause is usually an unsupported language or region — see below.",
                fix: .appleIntelligenceSettings))
        case .modelNotReady:
            out.append(AIAuditFinding(
                id: "download", status: .warning,
                title: "Model still downloading",
                detail: "Apple Intelligence is on, but the on-device model is still downloading in the background. Try again shortly.",
                fix: .appleIntelligenceSettings))
        case .available, .compiledOut:
            break // handled above
        }

        // Language hint — only meaningful when the device itself is eligible.
        if availability != .deviceNotEligible,
           !languageIsLikelySupported(primaryLanguageID) {
            out.append(AIAuditFinding(
                id: "language", status: .warning,
                title: "Language may be unsupported",
                detail: "Your Mac's primary language is \(primaryLanguageDisplayName) (\(primaryLanguageID)). Apple Intelligence supports specific languages and regional variants — e.g. English (US/UK), French, German, Spanish, Japanese, Chinese. If the Apple Intelligence toggle is missing, set your primary language to a supported one in Language & Region, then enable it.",
                fix: .languageSettings))
        }

        return out
    }

    /// Convenience: findings for the current live availability.
    public static var current: [AIAuditFinding] {
        findings(availability: LocalModelClient.shared.availability)
    }
}

public extension AIAuditFinding.Fix {
    /// Label for the one-click button that opens the relevant settings pane.
    var buttonLabel: String {
        switch self {
        case .appleIntelligenceSettings: return "Open Apple Intelligence Settings"
        case .languageSettings: return "Open Language & Region"
        }
    }

    #if os(macOS)
    /// Deep link to the specific System Settings pane (macOS only).
    var settingsURL: URL? {
        switch self {
        case .appleIntelligenceSettings:
            return URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")
        case .languageSettings:
            return URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")
        }
    }
    #endif

    /// Open the relevant settings in one click. On macOS this deep-links to the
    /// exact pane; on iOS it opens the app's Settings entry (iOS has no public
    /// deep link to specific system panes).
    func open() {
        #if os(macOS)
        if let url = settingsURL { NSWorkspace.shared.open(url) }
        #elseif os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
