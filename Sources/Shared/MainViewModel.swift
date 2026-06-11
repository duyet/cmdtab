import Combine
import SwiftUI
import os

@MainActor
public final class MainViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "app.minhagent", category: "ViewModel")
    @Published public var conversations: [Conversation] = []
    @Published public var selectedConversationId: UUID? = nil
    @Published public var presets: [Preset] = []
    @Published public var isStreaming: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var isSettingsOpen: Bool = false

    /// Active Settings tab — settable from anywhere (e.g. "Add API key" CTA).
    @Published public var settingsTab: String = "general" {
        didSet { UserDefaults.standard.set(settingsTab, forKey: "settingsTab") }
    }

    /// Keychain is only touched after this flips true (lazy, prompt-free launch).
    public private(set) var hasLoadedApiKey: Bool = false

    // Collapsible Sidebar Visibility
    @Published public var isSidebarVisible: Bool = true {
        didSet {
            UserDefaults.standard.set(isSidebarVisible, forKey: "isSidebarVisible")
        }
    }

    /// User-resizable sidebar width (drag the divider). Persisted UI state.
    @Published public var sidebarWidth: CGFloat = 260 {
        didSet { UserDefaults.standard.set(Double(sidebarWidth), forKey: "sidebarWidth") }
    }

    // Sidebar mode tab: "chat" | "plugins" | "automations"
    @Published public var sidebarMode: String = "chat" {
        didSet {
            UserDefaults.standard.set(sidebarMode, forKey: "sidebarMode")
        }
    }

    /// Display name shown in the welcome headline; set in Settings. UI state, not a secret.
    @Published public var userName: String = "" {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }

    /// Personality preset applied to every system prompt; set in Settings → Personalization.
    @Published public var personality: String = "default" {
        didSet { UserDefaults.standard.set(personality, forKey: "personality") }
    }

    /// Free-form custom instructions appended to every system prompt.
    @Published public var customInstructions: String = "" {
        didSet { UserDefaults.standard.set(customInstructions, forKey: "customInstructions") }
    }

    /// Memories toggle (no memory store yet — UX surface for the upcoming feature).
    @Published public var memoriesEnabled: Bool = false {
        didSet { UserDefaults.standard.set(memoriesEnabled, forKey: "memoriesEnabled") }
    }

    public static let personalityOptions: [(id: String, label: String, prompt: String)] = [
        ("default", "Default", ""),
        ("concise", "Concise", "Be extremely concise. Prefer short sentences and bullet points."),
        ("friendly", "Friendly", "Be warm, encouraging, and conversational."),
        ("professional", "Professional", "Use a formal, businesslike tone suitable for workplace writing."),
        ("creative", "Creative", "Be imaginative and exploratory; offer fresh angles and alternatives."),
    ]

    // Clipboard Action Banner
    @Published public var detectedClipboardText: String = ""
    @Published public var isClipboardBannerVisible: Bool = false

    // Focus signal — incremented whenever the composer should grab first-responder
    @Published public var composerFocusTick: Int = 0
    /// One-shot text handoff to the composer (starter suggestions). The
    /// composer consumes it and resets it to empty.
    @Published public var composerPrefill: String = ""

    public func prefillComposer(_ text: String) {
        composerPrefill = text
        composerFocusTick += 1
    }

    /// Date of the last message activity, used for daily-rollover detection.
    private var lastActivityDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastActivityDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastActivityDate") }
    }

    // Configurable Settings
    public var isLocalModelSupported: Bool {
        #if DISABLE_NATIVE_LLM
        return false
        #else
        if #available(macOS 15.0, iOS 18.0, *) {
            return true
        } else {
            return false
        }
        #endif
    }

    // The user may switch Local on even when unsupported — the composer shows
    // a warning notice instead of silently reverting the choice.
    @Published public var isLocalModelSelected: Bool = false {
        didSet {
            UserDefaults.standard.set(isLocalModelSelected, forKey: "isLocalModelSelected")
            updateStatusMessage()
        }
    }
    @Published public var apiProvider: String = "anyrouter" {
        didSet {
            UserDefaults.standard.set(apiProvider, forKey: "apiProvider")
            updateStatusMessage()
        }
    }
    @Published public var endpointUrl: String = "https://anyrouter.dev/api/v1" {
        didSet {
            if isApplyingEnvConfig { return }
            UserDefaults.standard.set(endpointUrl, forKey: "endpointUrl")
            updateStatusMessage()
        }
    }
    /// The default cloud model id used when no valid id is persisted.
    public static let defaultModelId = "google/gemini-3.5-flash"

    /// Known AnyRouter model ids surfaced in the composer picker. A persisted id
    /// outside this set is treated as obsolete and reset to `defaultModelId`.
    public static let knownModelIds: [String] = [
        "google/gemini-3.5-flash",
        "google/gemma-4-26b-a4b-it",
        "google/gemini-2.5-flash",
        "google/gemini-2.5-pro",
        "anthropic/claude-sonnet-4.6",
        "anthropic/claude-opus-4.2",
        "openai/gpt-5.4",
        "openai/gpt-5.4-mini",
    ]

    @Published public var modelName: String = MainViewModel.defaultModelId {
        didSet {
            UserDefaults.standard.set(modelName, forKey: "modelName")
            updateStatusMessage()
        }
    }

    /// Reasoning effort (low/medium/high) sent to cloud models that support it.
    /// UI preference — persisted in UserDefaults.
    @Published public var reasoningEffort: String = "medium" {
        didSet { UserDefaults.standard.set(reasoningEffort, forKey: "reasoningEffort") }
    }

    /// True when the active cloud model accepts a `reasoning_effort` parameter.
    public var modelSupportsReasoning: Bool { ModelCatalog.supportsReasoning(modelName) }
    @Published public var apiKey: String = "" {
        didSet {
            // Env-sourced keys are session-only; never persist them (AGENTS.md §3).
            if isApplyingEnvApiKey { return }
            // Debounce Keychain writes — avoid delete+add on every keystroke
            apiKeySaveTask?.cancel()
            apiKeySaveTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms
                guard !Task.isCancelled else { return }
                let saved = KeychainHelper.shared.save(
                    apiKey, service: "minhagent.app", account: "token"
                )
                if !saved {
                    Self.logger.error("Failed to save API key to Keychain")
                }
            }
        }
    }
    @Published public var preferredLanguage: String = "English" {
        didSet {
            UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage")
        }
    }

    /// "system" | "light" | "dark" — stored as rawValue in UserDefaults.
    @Published public var appearanceMode: String = "system" {
        didSet {
            UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    /// 0.9 = Small, 1.0 = Medium, 1.1 = Large.
    @Published public var fontScale: CGFloat = 1.0 {
        didSet {
            UserDefaults.standard.set(Double(fontScale), forKey: "fontScale")
        }
    }

    #if os(macOS)
    public func applyAppearance() {
        switch appearanceMode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
    #else
    public func applyAppearance() {}
    #endif

    private var currentTask: Task<Void, Never>? = nil
    private var apiKeySaveTask: Task<Void, Never>? = nil
    /// True while assigning an `.env.local`-sourced key, so the didSet skips Keychain persistence.
    private var isApplyingEnvApiKey = false
    /// True while applying env-sourced config (e.g. base URL), so didSet skips UserDefaults.
    private var isApplyingEnvConfig = false
    private var streamingConversationIndex: Int? = nil
    private var streamingMessageIndex: Int? = nil

    public init() {
        loadSettings()
        setupClipboardMonitor()

        // Prefer the on-device model by default when it's actually available
        // and the user hasn't made an explicit choice yet.
        if UserDefaults.standard.object(forKey: "isLocalModelSelected") == nil, isLocalModelSupported {
            self.isLocalModelSelected = true
        }

        updateStatusMessage()

        // Start with a default conversation if history is empty
        if conversations.isEmpty {
            startNewConversation(title: "General Chat")
        }
    }

    private func loadSettings() {
        self.isSidebarVisible = UserDefaults.standard.object(forKey: "isSidebarVisible") as? Bool ?? true
        self.settingsTab = UserDefaults.standard.string(forKey: "settingsTab") ?? "general"
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let storedWidth = UserDefaults.standard.double(forKey: "sidebarWidth")
        if storedWidth >= 220 && storedWidth <= 400 { self.sidebarWidth = CGFloat(storedWidth) }
        self.personality = UserDefaults.standard.string(forKey: "personality") ?? "default"
        self.customInstructions = UserDefaults.standard.string(forKey: "customInstructions") ?? ""
        self.memoriesEnabled = UserDefaults.standard.bool(forKey: "memoriesEnabled")
        self.sidebarMode = UserDefaults.standard.string(forKey: "sidebarMode") ?? "chat"
        self.isLocalModelSelected = UserDefaults.standard.bool(forKey: "isLocalModelSelected")
        self.apiProvider = UserDefaults.standard.string(forKey: "apiProvider") ?? "anyrouter"
        self.endpointUrl = UserDefaults.standard.string(forKey: "endpointUrl") ?? "https://anyrouter.dev/api/v1"
        // Drop obsolete persisted model ids (e.g. older OpenRouter free-tier slugs)
        // that are no longer in the known-model list, falling back to the current default.
        if let storedEffort = UserDefaults.standard.string(forKey: "reasoningEffort"),
            ModelCatalog.reasoningEfforts.contains(storedEffort)
        {
            self.reasoningEffort = storedEffort
        }

        let storedModel = UserDefaults.standard.string(forKey: "modelName")
        if let storedModel, MainViewModel.knownModelIds.contains(storedModel) {
            self.modelName = storedModel
        } else {
            self.modelName = MainViewModel.defaultModelId
        }
        // Keychain is read LAZILY (loadApiKeyIfNeeded), never at launch — a
        // launch-time read triggers a macOS permission prompt on every rebuild
        // because ad-hoc re-signing changes the app's code identity.
        self.preferredLanguage = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "English"
        self.appearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        let storedScale = UserDefaults.standard.double(forKey: "fontScale")
        self.fontScale = storedScale > 0 ? CGFloat(storedScale) : 1.0

        if let data = UserDefaults.standard.data(forKey: "presets"),
            let loadedPresets = try? JSONDecoder().decode([Preset].self, from: data)
        {
            self.presets = loadedPresets
        } else {
            self.presets = MainViewModel.defaultPresets()
            savePresets()
        }
    }

    public func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "presets")
        }
    }

    // MARK: Prompt-action (preset) editing — used by the sidebar Actions tab

    public func movePresets(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }

    public func addPreset() {
        presets.append(
            Preset(
                name: "New action", sfSymbol: "sparkles", systemPrompt: "Describe what to do with the clipboard text."))
        savePresets()
    }

    public func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        savePresets()
    }

    public func renamePreset(id: UUID, to name: String) {
        guard let i = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[i].name = name
        savePresets()
    }

    public func setPresetIcon(id: UUID, sfSymbol: String) {
        guard let i = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[i].sfSymbol = sfSymbol
        savePresets()
    }

    public func setPresetPrompt(id: UUID, prompt: String) {
        guard let i = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[i].systemPrompt = prompt
        savePresets()
    }

    public func resetPresets() {
        self.presets = MainViewModel.defaultPresets()
        savePresets()
    }

    private func setupClipboardMonitor() {
        PasteboardMonitor.shared.onClipboardChanged = { [weak self] text in
            guard let self = self else { return }
            // Notify when the copied text changes
            if text != self.detectedClipboardText && !self.isStreaming {
                self.detectedClipboardText = text
                self.isClipboardBannerVisible = true
            }
        }
        PasteboardMonitor.shared.startMonitoring()
    }

    public func updateStatusMessage() {
        if isLocalModelSelected {
            self.statusMessage = "Local (Apple Intelligence)"
        } else {
            let domain = URL(string: endpointUrl)?.host ?? "anyrouter.dev"
            self.statusMessage = "\(domain) // \(modelName)"
        }
    }

    public func toggleSettings() {
        isSettingsOpen.toggle()
        if isSettingsOpen { loadApiKeyIfNeeded() }
    }

    /// Open Settings on a specific tab (e.g. the "Add API key" CTA).
    public func openSettings(tab: String) {
        settingsTab = tab
        isSettingsOpen = true
        loadApiKeyIfNeeded()
    }

    /// Read the API key from the Keychain exactly once, on first need —
    /// never at launch, so opening the app never triggers a Keychain prompt.
    public func loadApiKeyIfNeeded() {
        guard !hasLoadedApiKey else { return }
        hasLoadedApiKey = true
        let stored = KeychainHelper.shared.read(service: "minhagent.app", account: "token") ?? ""
        if !stored.isEmpty && apiKey.isEmpty {
            apiKey = stored
        }
        // Dev fallback: .env.local / environment (never persisted to Keychain).
        if apiKey.isEmpty, let envKey = EnvFile.value(for: "ANYROUTER_API_KEY") {
            isApplyingEnvApiKey = true
            apiKey = envKey
            isApplyingEnvApiKey = false
            if let envBase = EnvFile.value(for: "ANYROUTER_BASE_URL"), !envBase.isEmpty {
                isApplyingEnvConfig = true
                endpointUrl = envBase
                isApplyingEnvConfig = false
            }
        }
    }

    public func startNewConversation(title: String, presetId: UUID? = nil) {
        let newConv = Conversation(title: title, presetId: presetId)
        self.conversations.insert(newConv, at: 0)
        self.selectedConversationId = newConv.id
        clearConversation()
        composerFocusTick += 1
    }

    public func selectConversation(id: UUID) {
        selectedConversationId = id
        clearConversation()
    }

    public func renameConversation(id: UUID, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let index = conversations.firstIndex(where: { $0.id == id })
        else { return }
        conversations[index].title = trimmed
    }

    public func deleteConversation(id: UUID) {
        // Cancel streaming if deleting the active conversation
        if selectedConversationId == id {
            currentTask?.cancel()
            currentTask = nil
            isStreaming = false
            clearStreamingIndices()
        }
        conversations.removeAll(where: { $0.id == id })
        if selectedConversationId == id {
            selectedConversationId = conversations.first?.id
        }
        if conversations.isEmpty {
            startNewConversation(title: "General Chat")
        }
    }

    public func sendMessage(content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isStreaming else { return }

        if selectedConversationId == nil {
            startNewConversation(title: "General Chat")
        }

        // Auto-compact if conversation history exceeds model's threshold
        compactIfNeeded()

        guard let activeId = selectedConversationId,
            let activeIndex = conversations.firstIndex(where: { $0.id == activeId })
        else { return }

        let userMsg = ChatMessage(role: "user", content: content)
        conversations[activeIndex].messages.append(userMsg)
        lastActivityDate = Date()

        isClipboardBannerVisible = false
        startLLMResponse(for: activeId)
    }

    /// Pick a Quick Action by index (⌘1-9). With clipboard text present this
    /// runs the preset against it immediately; otherwise it opens a fresh
    /// conversation primed with the preset and focuses the composer so the user
    /// can type their own input.
    public func pickPreset(index: Int) {
        guard index >= 0 && index < presets.count else { return }
        if !detectedClipboardText.isEmpty && isClipboardBannerVisible {
            runPresetWithClipboard(index: index)
        } else {
            let preset = presets[index]
            startNewConversation(title: preset.name, presetId: preset.id)
            prefillComposer("")  // focus the composer for this preset
        }
    }

    public func runPresetWithClipboard(index: Int) {
        guard index >= 0 && index < presets.count else { return }
        guard !detectedClipboardText.isEmpty else { return }

        let preset = presets[index]

        // Start a new conversation for this specific preset task
        let newTitle = preset.name
        startNewConversation(title: newTitle, presetId: preset.id)

        guard let activeId = selectedConversationId,
            let activeIndex = conversations.firstIndex(where: { $0.id == activeId })
        else { return }

        // Context contains both instructions and copied text
        let userMsg = ChatMessage(
            role: "user", content: detectedClipboardText,
            actionLabel: preset.name, isQuote: true)
        conversations[activeIndex].messages.append(userMsg)

        isClipboardBannerVisible = false
        startLLMResponse(for: activeId)
    }

    public func dismissClipboardBanner() {
        isClipboardBannerVisible = false
    }

    /// Called by the platform layer on NSApplication.didBecomeActiveNotification.
    /// Re-checks clipboard and applies daily-rollover logic.
    public func handleActivation() {
        // 1. Daily rollover: if last activity was a previous calendar day, start fresh.
        if let last = lastActivityDate {
            let cal = Calendar.current
            if !cal.isDateInToday(last) {
                startNewConversation(title: "General Chat")
            }
        }

        // 2. Re-check clipboard so quote card appears instantly on Cmd+Tab.
        if let newText = PasteboardMonitor.shared.detectNewContent() {
            if newText != detectedClipboardText {
                detectedClipboardText = newText
                isClipboardBannerVisible = true
            }
        } else if !detectedClipboardText.isEmpty {
            // Keep showing previously detected text even if changeCount hasn't advanced
            isClipboardBannerVisible = true
        }

        // 3. Signal composer to re-acquire focus.
        composerFocusTick += 1
    }

    private func startLLMResponse(for conversationId: UUID) {
        guard let activeIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let conversation = conversations[activeIndex]

        // Find instructions based on presetId (not title — avoids fragile string matching)
        var base = "You are a helpful engineering assistant. Respond concisely using markdown."
        if let pid = conversation.presetId,
            let matchedPreset = presets.first(where: { $0.id == pid })
        {
            base = matchedPreset.systemPrompt
        }
        let personalityPrompt =
            MainViewModel.personalityOptions.first(where: { $0.id == personality })?.prompt
        let systemInstructions = SystemPromptBuilder.assemble(
            base: base,
            preferredLanguage: preferredLanguage,
            personalityPrompt: personalityPrompt,
            customInstructions: customInstructions,
            contextSummary: conversation.compactedSummary)

        currentTask?.cancel()
        clearStreamingIndices()
        isStreaming = true

        // Append placeholder assistant message
        let assistantMsgId = UUID()
        let initialAssistantMsg = ChatMessage(id: assistantMsgId, role: "assistant", content: "")
        conversations[activeIndex].messages.append(initialAssistantMsg)

        // Cache indices for fast appendChunk — avoids O(n*m) per token
        streamingConversationIndex = activeIndex
        streamingMessageIndex = conversations[activeIndex].messages.count - 1

        // Select the active inference adapter from the Local/Cloud toggle state.
        if !isLocalModelSelected { loadApiKeyIfNeeded() }
        let adapter: InferenceAdapter =
            isLocalModelSelected
            ? LocalModelAdapter()
            : AnyRouterAdapter(
                endpointUrl: endpointUrl, apiKey: apiKey, model: modelName,
                reasoningEffort: modelSupportsReasoning ? reasoningEffort : nil)
        let historyMessages = Array(conversations[activeIndex].messages.dropLast())  // all except placeholder

        currentTask = Task { [weak self] in
            do {
                // Both backends conform to InferenceAdapter and yield text deltas,
                // so consumption is identical regardless of which is active.
                let stream = try await adapter.streamResponse(
                    instructions: systemInstructions,
                    history: historyMessages
                )
                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    self?.appendChunk(chunk: chunk, to: conversationId, messageId: assistantMsgId)
                }

                self?.isStreaming = false
                self?.clearStreamingIndices()
            } catch {
                guard !Task.isCancelled else { return }
                let text = (error as? APIError)?.userMessage ?? error.localizedDescription
                self?.appendChunk(chunk: text, to: conversationId, messageId: assistantMsgId)
                self?.markMessageAsError(conversationId: conversationId, messageId: assistantMsgId)
                self?.isStreaming = false
                self?.clearStreamingIndices()
            }
        }
    }

    private func markMessageAsError(conversationId: UUID, messageId: UUID) {
        guard let convIdx = conversations.firstIndex(where: { $0.id == conversationId }),
            let msgIdx = conversations[convIdx].messages.firstIndex(where: { $0.id == messageId })
        else { return }
        conversations[convIdx].messages[msgIdx].isError = true
    }

    private func appendChunk(chunk: String, to conversationId: UUID, messageId: UUID) {
        // Use cached indices when available, fallback to UUID lookup
        if let convIdx = streamingConversationIndex,
            let msgIdx = streamingMessageIndex,
            convIdx < conversations.count,
            msgIdx < conversations[convIdx].messages.count,
            conversations[convIdx].id == conversationId,
            conversations[convIdx].messages[msgIdx].id == messageId
        {
            conversations[convIdx].messages[msgIdx].content += chunk
        } else {
            // Fallback: UUID-based lookup
            guard let activeIndex = conversations.firstIndex(where: { $0.id == conversationId }),
                let msgIndex = conversations[activeIndex].messages.firstIndex(where: { $0.id == messageId })
            else {
                return
            }
            streamingConversationIndex = activeIndex
            streamingMessageIndex = msgIndex
            conversations[activeIndex].messages[msgIndex].content += chunk
        }
    }

    public func copyOutputToClipboard() {
        guard let activeId = selectedConversationId,
            let activeIndex = conversations.firstIndex(where: { $0.id == activeId }),
            let lastAssistantMsg = conversations[activeIndex].messages.last(where: { $0.role == "assistant" })
        else {
            return
        }

        let outputText = lastAssistantMsg.content
        guard !outputText.isEmpty else { return }

        PasteboardMonitor.shared.copyToClipboard(outputText)
    }

    public func clearConversation() {
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
        clearStreamingIndices()

        // Remove orphan empty assistant messages left from cancelled streams
        if let activeId = selectedConversationId,
            let idx = conversations.firstIndex(where: { $0.id == activeId })
        {
            conversations[idx].messages.removeAll { $0.role == "assistant" && $0.content.isEmpty }
        }
    }

    private func clearStreamingIndices() {
        streamingConversationIndex = nil
        streamingMessageIndex = nil
    }

    public static func defaultPresets() -> [Preset] {
        return [
            Preset(
                name: "Summarize",
                sfSymbol: "list.bullet",
                systemPrompt:
                    "Summarize the input into exactly 3 bullet points (TL;DR). Each bullet is one sentence, max 20 words. Return only the 3 bullets, no preamble."
            ),
            Preset(
                name: "Translate",
                sfSymbol: "globe",
                systemPrompt:
                    "Translate the input text into English. Preserve the original tone, register, and formatting as closely as possible. Return only the translation."
            ),
            Preset(
                name: "Explain",
                sfSymbol: "lightbulb",
                systemPrompt:
                    "Explain this in plain language as an expert talking to a smart non-expert. No jargon. No fluff. Structured prose or short bullets — whatever is clearest."
            ),
            Preset(
                name: "Fix Grammar",
                sfSymbol: "textformat.abc",
                systemPrompt:
                    "Correct all spelling, grammar, and punctuation errors in the input. Return only the corrected text with no commentary or explanation."
            ),
            Preset(
                name: "Action Items",
                sfSymbol: "checklist",
                systemPrompt:
                    "Extract all action items from the input as a markdown checklist. For each item include the owner and deadline if mentioned. Return only the checklist."
            ),
            Preset(
                name: "Rewrite Pro",
                sfSymbol: "pencil.and.scribble",
                systemPrompt:
                    "Rewrite the input in a professional, clear, and courteous style. Remove filler words and vague phrasing. Return only the rewritten text."
            ),
            Preset(
                name: "Explain Code",
                sfSymbol: "chevron.left.forwardslash.chevron.right",
                systemPrompt:
                    "Explain what this code does: describe its purpose, key inputs and outputs, and identify one significant risk or edge case. Use plain language with minimal jargon."
            ),
            Preset(
                name: "English Rewrite",
                sfSymbol: "character.bubble",
                systemPrompt:
                    "Rewrite the input as natural, fluent, native-sounding English. Correct all grammar, spelling, and punctuation; smooth out awkward phrasing and non-idiomatic constructions; and preserve the original meaning, tone, and level of formality. Do not add or remove information, and do not translate proper nouns or technical terms. If the input is already a different language, translate it to English first, then refine. Return only the rewritten English text, with no quotes, labels, or commentary."
            ),
            Preset(
                name: "What did they say?",
                sfSymbol: "quote.bubble",
                systemPrompt:
                    "Interpret what the input is really saying for a reader who may have missed the nuance. In plain, simple language: (1) restate the core message in one or two sentences, (2) decode any jargon, acronyms, slang, idioms, sarcasm, or implied/indirect meaning, and (3) note the tone or intent if it matters (e.g. polite refusal, complaint, joke). Be faithful to the source and do not invent details. Keep it short — return only the interpretation, no preamble."
            ),
            Preset(
                name: "Draw / Explain",
                sfSymbol: "flowchart",
                systemPrompt:
                    "Explain the input clearly and illustrate it with a diagram. First give a brief plain-language explanation (2-4 sentences or short bullets). Then choose the most fitting Mermaid diagram type — flowchart for processes, sequenceDiagram for interactions, classDiagram for structure, stateDiagram-v2 for state, mindmap for concepts — and output exactly one valid, syntactically correct diagram in a fenced ```mermaid code block. Keep node labels concise, avoid unsupported syntax, and make sure the diagram reflects the explanation."
            ),
        ]
    }
}
