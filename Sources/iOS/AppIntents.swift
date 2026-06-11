#if os(iOS)
import AppIntents
import Foundation

// MARK: - Runtime handoff
/// Single routing surface for intents that open the app. Intents enqueue a
/// closure; the scene flushes it once the live `MainViewModel` is available.
@MainActor
final class AppIntentRouter {
    static let shared = AppIntentRouter()
    weak var viewModel: MainViewModel?
    private var pending: ((MainViewModel) -> Void)?
    private init() {}

    func enqueue(_ action: @escaping (MainViewModel) -> Void) {
        pending = action
        flush()
    }

    /// Apply any queued action. Called on scene activation and right after enqueue.
    func flush() {
        guard let vm = viewModel, let action = pending else { return }
        pending = nil
        action(vm)
    }
}

// MARK: - Preset store (works whether or not the app is running)
/// Reads persisted Quick Actions directly so the Shortcuts editor can list them
/// even when the app process isn't active.
private enum PresetStore {
    static func all() -> [Preset] {
        guard let data = UserDefaults.standard.data(forKey: "presets"),
            let presets = try? JSONDecoder().decode([Preset].self, from: data)
        else { return [] }
        return presets
    }

    static func first(id: UUID) -> Preset? { all().first { $0.id == id } }
}

// MARK: - Quick Action entity
struct PresetEntity: AppEntity, Identifiable {
    let id: UUID
    let name: String
    let symbol: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Quick Action"
    static let defaultQuery = PresetQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }

    init(_ preset: Preset) {
        self.id = preset.id
        self.name = preset.name
        self.symbol = preset.sfSymbol
    }
}

struct PresetQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [PresetEntity] {
        PresetStore.all().filter { identifiers.contains($0.id) }.map(PresetEntity.init)
    }

    func suggestedEntities() async throws -> [PresetEntity] {
        PresetStore.all().map(PresetEntity.init)
    }
}

// MARK: - Intents

/// Ask MinhAgent a prompt — opens the app on a fresh chat and sends it.
struct AskMinhAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask MinhAgent"
    static let description = IntentDescription("Start a new chat and send a prompt to MinhAgent.")
    static let openAppWhenRun = true

    @Parameter(title: "Prompt", requestValueDialog: "What do you want to ask?")
    var prompt: String

    func perform() async throws -> some IntentResult {
        let prompt = self.prompt
        await MainActor.run {
            AppIntentRouter.shared.enqueue { vm in
                vm.startNewConversation(title: "General Chat")
                vm.sendMessage(content: prompt)
            }
        }
        return .result()
    }
}

/// Open MinhAgent on a fresh conversation, optionally pre-filling the composer.
struct NewChatIntent: AppIntent {
    static let title: LocalizedStringResource = "New MinhAgent Chat"
    static let description = IntentDescription("Open MinhAgent on a new, empty conversation.")
    static let openAppWhenRun = true

    @Parameter(title: "Starting text")
    var text: String?

    func perform() async throws -> some IntentResult {
        let text = self.text
        await MainActor.run {
            AppIntentRouter.shared.enqueue { vm in
                vm.startNewConversation(title: "New Chat")
                if let text, !text.isEmpty { vm.prefillComposer(text) }
            }
        }
        return .result()
    }
}

/// Run a saved Quick Action on some text — opens the app and streams the result.
struct RunQuickActionIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Quick Action"
    static let description = IntentDescription("Run a MinhAgent Quick Action on some text.")
    static let openAppWhenRun = true

    @Parameter(title: "Quick Action")
    var action: PresetEntity

    @Parameter(title: "Text", requestValueDialog: "What text should it run on?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$action) on \(\.$text)")
    }

    func perform() async throws -> some IntentResult {
        let presetId = action.id
        let text = self.text
        await MainActor.run {
            AppIntentRouter.shared.enqueue { vm in
                vm.runQuickAction(presetId: presetId, text: text)
            }
        }
        return .result()
    }
}

// MARK: - App Shortcuts (Siri / Spotlight phrases)
struct MinhAgentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskMinhAgentIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask a question in \(.applicationName)",
            ],
            shortTitle: "Ask",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: NewChatIntent(),
            phrases: [
                "New chat in \(.applicationName)",
                "Start a \(.applicationName) chat",
            ],
            shortTitle: "New Chat",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: RunQuickActionIntent(),
            phrases: [
                "Run a \(.applicationName) Quick Action",
            ],
            shortTitle: "Quick Action",
            systemImageName: "bolt"
        )
    }
}
#endif
