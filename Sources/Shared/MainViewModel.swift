import Combine
import SwiftUI
import os
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftData)
import SwiftData
#endif

@MainActor
public final class MainViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "app.minhagent", category: "ViewModel")
    @Published public var conversations: [Conversation] = []
    @Published public var selectedConversationId: UUID? = nil
    @Published public var selectedConversationIds: Set<UUID> = []
    @Published public var lastSelectedConversationId: UUID? = nil
    @Published public var presets: [Preset] = []
    @Published public var selectedPresetIdForDetail: UUID? = nil
    @Published public var isStreaming: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var isSettingsOpen: Bool = false {
        didSet {
            if isSettingsOpen {
                isSearchPaletteVisible = false
            }
        }
    }

    /// Active Settings tab — settable from anywhere (e.g. "Add API key" CTA).
    @Published public var settingsTab: String = "general" {
        didSet { UserDefaults.standard.set(settingsTab, forKey: "settingsTab") }
    }

    /// Keychain is only touched after this flips true (lazy, prompt-free launch).
    public private(set) var hasLoadedApiKey: Bool = false
    @Published public var anyRouterConnectionTitle: String = "AnyRouter not connected"
    @Published public var anyRouterConnectionDetail: String = "Connect a Keychain-stored API key to verify access and load live models."
    @Published public var isAnyRouterConnecting: Bool = false
    @Published public var availableCloudModelEntries: [ModelCatalog.Entry] = ModelCatalog.entries

    // Collapsible Sidebar Visibility — always starts visible; the user
    // hides it per-session via the sidebar icon / ⌘B.
    @Published public var isSidebarVisible: Bool = true

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

    /// Base system prompt. Editable in Settings, persisted to UserDefaults.
    @Published public var systemPrompt: String = MainViewModel.defaultSystemPrompt {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt") }
    }

    public static let defaultSystemPrompt =
        "You are a helpful engineering assistant. Respond concisely using markdown. "
        + "When useful, emit fenced `tool` blocks with name/status/input/output fields, "
        + "fenced `chart` blocks with title and label:value rows, and markdown images."

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
    /// Quick Action the user has picked but not yet sent — shown as a small
    /// header line above the composer's text input.
    @Published public var selectedPresetIndex: Int? = nil
 
    /// Set of enabled on-device tool names (e.g., "calculator", "system_clock")
    @Published public var enabledLocalTools: Set<String> = ["calculator", "system_clock"] {
        didSet {
            let array = Array(enabledLocalTools)
            UserDefaults.standard.set(array, forKey: "enabledLocalTools")
        }
    }

    /// Sidebar search field visibility — toggled from the window toolbar's
    /// search item (next to the sidebar toggle).
    @Published public var isSidebarSearchVisible: Bool = false

    /// Floating command-palette search overlay (Spotlight / ⌘K style).
    @Published public var isSearchPaletteVisible: Bool = false

    /// Per-day usage counters (sessions / messages / token estimates) for the
    /// welcome activity calendar. Counts only — content never persists.
    @Published public var usageByDay: [String: DayUsage] = UsageStats.load()

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

    /// Which local model backend: "on-device" (FoundationModels) or "private-cloud" (placeholder).
    @Published public var localModelMode: String = "on-device" {
        didSet { UserDefaults.standard.set(localModelMode, forKey: "localModelMode") }
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
    public var modelSupportsReasoning: Bool {
        ModelCatalog.supportsReasoning(modelName, in: availableCloudModelEntries)
    }

    public var cloudModelEntries: [ModelCatalog.Entry] {
        ModelCatalog.mergedEntries(remote: availableCloudModelEntries, selectedModelId: modelName)
    }
    @Published public var apiKey: String = "" {
        didSet {
            if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                anyRouterConnectionTitle = "AnyRouter not connected"
                anyRouterConnectionDetail = "Connect a Keychain-stored API key to verify access and load live models."
            } else if anyRouterConnectionTitle == "AnyRouter not connected" {
                anyRouterConnectionTitle = "AnyRouter key saved"
                anyRouterConnectionDetail = "Verify the key to load upstream models and confirm the connection."
            }
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
            AppFont.userScale = fontScale
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
        loadConversations()

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
        self.settingsTab = UserDefaults.standard.string(forKey: "settingsTab") ?? "general"
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        let storedWidth = UserDefaults.standard.double(forKey: "sidebarWidth")
        if storedWidth >= 220 && storedWidth <= 400 { self.sidebarWidth = CGFloat(storedWidth) }
        self.personality = UserDefaults.standard.string(forKey: "personality") ?? "default"
        self.customInstructions = UserDefaults.standard.string(forKey: "customInstructions") ?? ""
        self.systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? MainViewModel.defaultSystemPrompt
        self.memoriesEnabled = UserDefaults.standard.bool(forKey: "memoriesEnabled")
        self.sidebarMode = UserDefaults.standard.string(forKey: "sidebarMode") ?? "chat"
        self.isLocalModelSelected = UserDefaults.standard.bool(forKey: "isLocalModelSelected")
        self.apiProvider = UserDefaults.standard.string(forKey: "apiProvider") ?? "anyrouter"
        self.endpointUrl = UserDefaults.standard.string(forKey: "endpointUrl") ?? "https://anyrouter.dev/api/v1"
        if let storedEffort = UserDefaults.standard.string(forKey: "reasoningEffort"),
            ModelCatalog.reasoningEfforts.contains(storedEffort)
        {
            self.reasoningEffort = storedEffort
        }

        let storedModel = UserDefaults.standard.string(forKey: "modelName")
        if let storedModel, !storedModel.isEmpty {
            self.modelName = storedModel
        } else {
            self.modelName = MainViewModel.defaultModelId
        }
        if let array = UserDefaults.standard.stringArray(forKey: "enabledLocalTools") {
            self.enabledLocalTools = Set(array)
        } else {
            self.enabledLocalTools = ["calculator", "system_clock"]
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
        if isSettingsOpen {
            loadApiKeyIfNeeded()
        }
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
        if !apiKey.isEmpty {
            anyRouterConnectionTitle = "AnyRouter key saved"
            anyRouterConnectionDetail = "Verify the key to load upstream models and confirm the connection."
        }
    }

    public func connectAnyRouter() {
        apiProvider = "anyrouter"
        endpointUrl = "https://anyrouter.dev/api/v1"
        loadApiKeyIfNeeded()
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            anyRouterConnectionTitle = "Add an AnyRouter API key"
            anyRouterConnectionDetail = "Create a key in AnyRouter, then paste it here. It is saved only in Keychain."
            openAnyRouterKeysDashboard()
            return
        }
        verifyAnyRouterConnection()
    }

    public func verifyAnyRouterConnection() {
        loadApiKeyIfNeeded()
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            anyRouterConnectionTitle = "AnyRouter not connected"
            anyRouterConnectionDetail = "Paste an API key or open the AnyRouter dashboard to create one."
            return
        }
        isAnyRouterConnecting = true
        anyRouterConnectionTitle = "Checking AnyRouter..."
        anyRouterConnectionDetail = "Verifying the Keychain credential and loading the live model catalog."
        Task { [weak self] in
            do {
                guard let self else { return }
                let summary = try await APIClient.shared.inspectAnyRouterKey(
                    endpointUrl: self.endpointUrl,
                    apiKey: key
                )
                let models = try await APIClient.shared.fetchAnyRouterModels(
                    endpointUrl: self.endpointUrl,
                    apiKey: key
                )
                await MainActor.run {
                    self.availableCloudModelEntries = models.isEmpty ? ModelCatalog.entries : models
                    self.anyRouterConnectionTitle = "AnyRouter connected"
                    self.anyRouterConnectionDetail = "\(summary.displayText) · \(self.availableCloudModelEntries.count) models loaded"
                    self.isAnyRouterConnecting = false
                    self.isLocalModelSelected = false
                    self.updateStatusMessage()
                }
            } catch {
                await MainActor.run {
                    self?.availableCloudModelEntries = ModelCatalog.entries
                    self?.anyRouterConnectionTitle = "AnyRouter check failed"
                    self?.anyRouterConnectionDetail = (error as? APIError)?.userMessage ?? error.localizedDescription
                    self?.isAnyRouterConnecting = false
                }
            }
        }
    }

    public func openAnyRouterKeysDashboard() {
        guard let url = URL(string: "https://anyrouter.dev/dashboard/keys") else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    public func startNewConversation(title: String, presetId: UUID? = nil) {
        selectedPresetIdForDetail = nil
        // Clean up any old empty conversations (not the one we're about to create).
        conversations.removeAll { conv in
            conv.messages.isEmpty && conv.id != selectedConversationId
        }

        let newConv = Conversation(title: title, presetId: presetId)
        self.conversations.insert(newConv, at: 0)
        self.selectedConversationId = newConv.id
        selectedConversationIds = [newConv.id]
        lastSelectedConversationId = newConv.id
        clearConversation()
        composerFocusTick += 1
        recordUsage { $0.sessions += 1 }
    }

    /// Toggle the sidebar search field from the window toolbar. Makes sure the
    /// sidebar is visible and on the Chat tab so the field can actually appear.
    public func toggleSidebarSearch() {
        // Now opens the floating command palette instead of inline sidebar search.
        if isSearchPaletteVisible {
            hideSearchPalette()
        } else {
            showSearchPalette()
        }
    }

    public func showSearchPalette() {
        guard !isSettingsOpen else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            isSidebarSearchVisible = false
            isSearchPaletteVisible = true
        }
    }

    public func hideSearchPalette() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isSearchPaletteVisible = false
        }
    }

    /// Mutate today's usage bucket and persist the counters.
    private func recordUsage(_ mutate: (inout DayUsage) -> Void) {
        let key = UsageStats.dayKey()
        var day = usageByDay[key] ?? DayUsage()
        mutate(&day)
        usageByDay[key] = day
        UsageStats.save(usageByDay)
    }

    public func selectConversation(id: UUID) {
        selectedPresetIdForDetail = nil
        selectedConversationId = id
        selectedConversationIds = [id]
        lastSelectedConversationId = id
        clearConversation()
    }

    /// Multi-select with shift (range) and cmd (toggle) support.
    public func selectConversation(id: UUID, shift: Bool, cmd: Bool) {
        selectedPresetIdForDetail = nil
        if shift, let lastId = lastSelectedConversationId {
            // Range select from last selected to clicked
            let ids = conversations.map(\.id)
            guard let fromIdx = ids.firstIndex(of: lastId),
                  let toIdx = ids.firstIndex(of: id) else { return }
            let range = min(fromIdx, toIdx)...max(fromIdx, toIdx)
            selectedConversationIds = Set(ids[range])
            selectedConversationId = id
        } else if cmd {
            // Toggle individual item
            if selectedConversationIds.contains(id) {
                selectedConversationIds.remove(id)
                if selectedConversationId == id {
                    selectedConversationId = selectedConversationIds.first ?? conversations.first?.id
                }
            } else {
                selectedConversationIds.insert(id)
                selectedConversationId = id
            }
            lastSelectedConversationId = id
        } else {
            // Normal click — single select
            selectedConversationIds = [id]
            selectedConversationId = id
            lastSelectedConversationId = id
        }
    }

    public func deleteSelectedConversations() {
        guard !selectedConversationIds.isEmpty else { return }
        // Cancel streaming if active conversation is being deleted
        if let activeId = selectedConversationId, selectedConversationIds.contains(activeId) {
            currentTask?.cancel()
            currentTask = nil
            isStreaming = false
            clearStreamingIndices()
        }
        #if canImport(SwiftData)
        if modelContext != nil {
            for id in selectedConversationIds {
                deletePersistedConversation(id: id)
            }
        }
        #endif
        conversations.removeAll(where: { selectedConversationIds.contains($0.id) })
        selectedConversationIds = []
        lastSelectedConversationId = nil
        selectedConversationId = conversations.first?.id
        if conversations.isEmpty {
            startNewConversation(title: "General Chat")
        } else {
            saveConversations()
        }
    }

    public var isMultiSelect: Bool {
        selectedConversationIds.count > 1
    }

    /// Run a saved Quick Action on explicit text. Used by App Intents / Shortcuts
    /// so the action works from Siri, Spotlight, and the Shortcuts app.
    public func runQuickAction(presetId: UUID, text: String) {
        let preset = presets.first { $0.id == presetId }
        startNewConversation(title: preset?.name ?? "Quick Action", presetId: presetId)
        sendMessage(content: text)
    }

    public func renameConversation(id: UUID, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let index = conversations.firstIndex(where: { $0.id == id })
        else { return }
        conversations[index].title = trimmed
        saveConversations()
    }

    public func deleteConversation(id: UUID) {
        // Cancel streaming if deleting the active conversation
        if selectedConversationId == id {
            currentTask?.cancel()
            currentTask = nil
            isStreaming = false
            clearStreamingIndices()
        }
        #if canImport(SwiftData)
        if modelContext != nil {
            deletePersistedConversation(id: id)
        }
        #endif
        conversations.removeAll(where: { $0.id == id })
        if selectedConversationId == id {
            selectedConversationId = conversations.first?.id
        }
        if conversations.isEmpty {
            startNewConversation(title: "General Chat")
        } else {
            saveConversations()
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

        // Auto-title: use the first user message to generate a conversation title.
        if conversations[activeIndex].messages.filter({ $0.role == "user" }).count == 1 {
            let firstLine = content
                .split(separator: "\n", omittingEmptySubsequences: true).first
                .map(String.init) ?? content
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            conversations[activeIndex].title = String(trimmed.prefix(50))
        }

        lastActivityDate = Date()
        recordUsage {
            $0.messages += 1
            $0.tokens += UsageStats.estimateTokens(content)
        }

        isClipboardBannerVisible = false
        startLLMResponse(for: activeId)
        saveConversations()
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
            // No clipboard: just mark the preset as selected — the composer
            // shows it above the input. No conversation is created until send.
            selectedPresetIndex = index
            prefillComposer("")  // focus the composer for this preset
        }
    }

    /// Run the selected preset against text the user typed (no clipboard).
    /// Creates the conversation only now, at send time.
    public func runPresetWithInput(index: Int, content: String) {
        guard index >= 0 && index < presets.count else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let preset = presets[index]
        startNewConversation(title: preset.name, presetId: preset.id)
        selectedPresetIndex = nil
        sendMessage(content: trimmed)
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
        recordUsage {
            $0.messages += 1
            $0.tokens += UsageStats.estimateTokens(detectedClipboardText)
        }

        isClipboardBannerVisible = false
        selectedPresetIndex = nil
        // Consume the clipboard text so handleActivation doesn't resurface the
        // banner for content already acted on.
        detectedClipboardText = ""
        startLLMResponse(for: activeId)
        saveConversations()
    }

    public func dismissClipboardBanner() {
        isClipboardBannerVisible = false
        selectedPresetIndex = nil
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
        var base = systemPrompt
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
            userName: userName,
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
            ? LocalModelAdapter(enabledTools: enabledLocalTools)
            : AnyRouterAdapter(
                endpointUrl: endpointUrl, apiKey: apiKey, model: modelName,
                reasoningEffort: modelSupportsReasoning ? reasoningEffort : nil)
        let historyMessages = Array(conversations[activeIndex].messages.dropLast())  // all except placeholder
        
        // Generate and store raw request details for this conversation
        let rawRequestDetails: String
        if isLocalModelSelected {
            let prompt = historyMessages.last(where: { $0.role == "user" })?.content ?? ""
            let priorTurns = historyMessages.dropLast()
            var toolsArray: [[String: String]] = []
            if enabledLocalTools.contains("calculator") {
                toolsArray.append(["name": "calculator", "description": "Evaluate simple mathematical expressions"])
            }
            if enabledLocalTools.contains("system_clock") {
                toolsArray.append(["name": "system_clock", "description": "Get the current system date and time"])
            }
            var parameters: [String: Any] = [
                "framework": "FoundationModels (macOS 26)",
                "stream": true
            ]
            if !toolsArray.isEmpty {
                parameters["tools"] = toolsArray
            }
            let messagesArray: [[String: String]] = priorTurns.map { [
                "role": $0.role,
                "content": String($0.content.prefix(200))
            ] }
            let localRequest: [String: Any] = [
                "model": "Apple Foundation Models (On-Device)",
                "target_url": "local://on-device-inference",
                "parameters": parameters,
                "system_instructions": systemInstructions,
                "prompt": prompt,
                "history_turns": priorTurns.count,
                "messages": messagesArray
            ]
            if let data = try? JSONSerialization.data(withJSONObject: localRequest, options: [.prettyPrinted, .sortedKeys]),
               let jsonStr = String(data: data, encoding: .utf8) {
                rawRequestDetails = jsonStr
            } else {
                rawRequestDetails = "{ \"error\": \"Failed to serialize request info.\" }"
            }
        } else {
            let formatted = AnyRouterAdapter.formatMessages(
                instructions: systemInstructions,
                history: historyMessages.map { (role: $0.role, content: $0.content) }
            )
            var params: [String: Any] = [
                "stream": true,
                "stream_options": ["include_usage": true]
            ]
            if modelSupportsReasoning {
                params["reasoning_effort"] = reasoningEffort
            }
            let targetUrl = AnyRouterRequestFactory.normalizedURLString(from: endpointUrl)
            let cloudRequest: [String: Any] = [
                "model": modelName,
                "target_url": targetUrl,
                "parameters": params,
                "messages": formatted
            ]
            if let data = try? JSONSerialization.data(withJSONObject: cloudRequest, options: [.prettyPrinted, .sortedKeys]),
               let jsonStr = String(data: data, encoding: .utf8) {
                rawRequestDetails = jsonStr
            } else {
                rawRequestDetails = "{ \"error\": \"Failed to serialize request info.\" }"
            }
        }
        conversations[activeIndex].lastRawRequestDetails = rawRequestDetails

        // Capture serialized transcript entries for local model (if any).
        let storedEntries = isLocalModelSelected
            ? conversations[activeIndex].localTranscriptEntries ?? []
            : []
        let userPrompt = historyMessages.last(where: { $0.role == "user" })?.content ?? ""

        currentTask = Task { [weak self] in
            do {
                let stream: AsyncThrowingStream<StreamChunk, Error>
                if let localAdapter = adapter as? LocalModelAdapter {
                    stream = try await localAdapter.streamResponse(
                        instructions: systemInstructions,
                        history: historyMessages,
                        transcriptEntries: storedEntries
                    )
                } else {
                    stream = try await adapter.streamResponse(
                        instructions: systemInstructions,
                        history: historyMessages
                    )
                }

                let startTime = ContinuousClock.now
                var firstChunkTime: ContinuousClock.Instant?
                var capturedUsage: StreamUsage?

                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    switch chunk {
                    case .delta(let text):
                        if firstChunkTime == nil { firstChunkTime = ContinuousClock.now }
                        self?.appendChunk(chunk: text, to: conversationId, messageId: assistantMsgId)
                    case .usage(let usage):
                        capturedUsage = usage
                    }
                }

                // Assemble inference metrics.
                let endTime = ContinuousClock.now
                let totalMs = Self.durationMs(endTime - startTime)
                let ttftMs = firstChunkTime.map { Self.durationMs($0 - startTime) }

                var metrics = InferenceMetrics()
                metrics.model = capturedUsage?.model
                    ?? (self?.isLocalModelSelected == true ? "Apple Foundation Models" : self?.modelName)
                metrics.ttftMs = ttftMs
                metrics.totalMs = totalMs > 0 ? totalMs : nil

                if let usage = capturedUsage {
                    metrics.inputTokens = usage.promptTokens
                    metrics.outputTokens = usage.completionTokens
                    metrics.reasoningTokens = usage.reasoningTokens
                    // Estimate cost from model pricing + token counts.
                    if let modelId = metrics.model,
                       let entry = ModelCatalog.entry(for: modelId) {
                        metrics.costUsd = entry.estimateCost(
                            inputTokens: usage.promptTokens,
                            outputTokens: usage.completionTokens
                        )
                    }
                } else if let convIdx = self?.conversations.firstIndex(where: { $0.id == conversationId }),
                    let content = self?.conversations[convIdx]
                        .messages.first(where: { $0.id == assistantMsgId })?.content {
                    // Local model: estimate tokens from content length.
                    metrics.outputTokens = UsageStats.estimateTokens(content)
                }

                // Write metrics to the message.
                if let convIdx = self?.conversations.firstIndex(where: { $0.id == conversationId }),
                   let msgIdx = self?.conversations[convIdx].messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self?.conversations[convIdx].messages[msgIdx].inferenceMetrics = metrics
                    self?.conversations[convIdx].messages[msgIdx].renderBlocks = AgentResponseBlock.parse(
                        self?.conversations[convIdx].messages[msgIdx].content ?? "")
                }

                // Update serialized transcript entries for the next local model call.
                if self?.isLocalModelSelected == true,
                   let idx = self?.conversations.firstIndex(where: { $0.id == conversationId }) {
                    var updated = storedEntries
                    updated.append(TranscriptEntryData(role: "user", content: userPrompt))
                    let assistantContent = self?.conversations[idx]
                        .messages.first(where: { $0.id == assistantMsgId })?.content ?? ""
                    updated.append(TranscriptEntryData(role: "assistant", content: assistantContent))
                    self?.conversations[idx].localTranscriptEntries = updated
                }

                self?.finalizeAssistantUsage(conversationId: conversationId, messageId: assistantMsgId)
                self?.isStreaming = false
                self?.clearStreamingIndices()
                self?.saveConversations()
            } catch {
                guard !Task.isCancelled else { return }
                let text = (error as? APIError)?.userMessage ?? error.localizedDescription
                self?.appendChunk(chunk: text, to: conversationId, messageId: assistantMsgId)
                self?.markMessageAsError(conversationId: conversationId, messageId: assistantMsgId)
                self?.isStreaming = false
                self?.clearStreamingIndices()
                self?.saveConversations()
            }
        }
    }

    /// Count the completed assistant reply (message + token estimate).
    private func finalizeAssistantUsage(conversationId: UUID, messageId: UUID) {
        guard let convIdx = conversations.firstIndex(where: { $0.id == conversationId }),
            let msg = conversations[convIdx].messages.first(where: { $0.id == messageId }),
            !msg.content.isEmpty
        else { return }
        recordUsage {
            $0.messages += 1
            $0.tokens += UsageStats.estimateTokens(msg.content)
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

    /// Retry: remove the last error assistant message and resend the preceding user message.
    public func retryLastMessage() {
        guard let activeId = selectedConversationId,
              let idx = conversations.firstIndex(where: { $0.id == activeId }),
              let lastMsg = conversations[idx].messages.last,
              lastMsg.role == "assistant" && lastMsg.isError
        else { return }

        // Remove the error message.
        conversations[idx].messages.removeLast()

        // Find the preceding user message to resend.
        guard let lastUser = conversations[idx].messages.last(where: { $0.role == "user" }) else { return }

        // Remove that user message too so sendMessage re-appends it cleanly.
        conversations[idx].messages.removeLast()
        sendMessage(content: lastUser.content)
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
        saveConversations()
    }

    public func getRawRequestDetails() -> String {
        guard let activeId = selectedConversationId,
              let activeIndex = conversations.firstIndex(where: { $0.id == activeId }) else {
            return "{ \"error\": \"No active conversation selected.\" }"
        }
        
        let conversation = conversations[activeIndex]
        if let savedDetails = conversation.lastRawRequestDetails {
            return savedDetails
        }
        return "{ \"info\": \"No request has been sent yet in this conversation.\" }"
    }

    private func clearStreamingIndices() {
        streamingConversationIndex = nil
        streamingMessageIndex = nil
    }

    private func conversationsFileUrl() -> URL? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = appSupport.appendingPathComponent("MinhAgent", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        }
        return appDir.appendingPathComponent("conversations.json")
    }

    public func saveConversations() {
        #if canImport(SwiftData)
        if modelContext != nil {
            for conversation in conversations {
                saveConversation(conversation)
            }
            return
        }
        #endif

        guard let url = conversationsFileUrl() else { return }
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("Failed to save conversations: \(error.localizedDescription)")
        }
    }

    private func loadConversations() {
        #if canImport(SwiftData)
        if modelContext != nil {
            loadPersistedConversations()
            return
        }
        #endif

        guard let url = conversationsFileUrl() else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Conversation].self, from: data)
            self.conversations = decoded
            if let firstConv = decoded.first {
                self.selectedConversationId = firstConv.id
                self.selectedConversationIds = [firstConv.id]
            }
        } catch {
            Self.logger.error("Failed to load conversations: \(error.localizedDescription)")
        }
    }

    // MARK: - SwiftData Database Helpers
    #if canImport(SwiftData)
    var modelContext: ModelContext?

    public func configurePersistence(_ context: ModelContext) {
        self.modelContext = context
        loadPersistedConversations()
    }

    private func loadPersistedConversations() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<PersistedConversation>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let persisted = try? modelContext.fetch(descriptor) else { return }
        let loaded = persisted.map { $0.toVolatile() }
        guard !loaded.isEmpty else { return }
        self.conversations = loaded
        if let firstConv = loaded.first {
            self.selectedConversationId = firstConv.id
            self.selectedConversationIds = [firstConv.id]
        }
    }

    private func saveConversation(_ conversation: Conversation) {
        guard let modelContext else { return }
        let id = conversation.id
        if let existing = try? modelContext.fetch(
            FetchDescriptor<PersistedConversation>(predicate: #Predicate { $0.id == id })
        ).first {
            modelContext.delete(existing)
        }
        modelContext.insert(PersistedConversation(from: conversation))
        try? modelContext.save()
    }

    private func deletePersistedConversation(id: UUID) {
        guard let modelContext else { return }
        if let existing = try? modelContext.fetch(
            FetchDescriptor<PersistedConversation>(predicate: #Predicate { $0.id == id })
        ).first {
            modelContext.delete(existing)
            try? modelContext.save()
        }
    }
    #endif

    public static func defaultPresets() -> [Preset] {
        return [
            Preset(
                name: "Fix English",
                sfSymbol: "textformat.abc",
                systemPrompt:
                    "You are an English copy editor. Fix the grammar, spelling, punctuation, and word choice in the input so it reads naturally in simple, easy English. Preserve the original meaning, tone, and structure. If the input is Markdown, return the same Markdown formatting. Do not translate, add, remove, or explain anything. Return only the corrected text — no quotation marks, no \">\" blockquotes, no labels or commentary."
            ),
            Preset(
                name: "What did they say?",
                sfSymbol: "quote.bubble",
                systemPrompt:
                    "Interpret what the input really means for a reader who may have missed the nuance, and explain it in the response language. (1) Restate the core message in one or two sentences. (2) Decode any jargon, acronyms, slang, idioms, sarcasm, or implied/indirect meaning. (3) Note the tone or intent if it matters (e.g. polite refusal, complaint, joke). Be faithful to the source and do not invent details. Return only the explanation, no preamble."
            ),
            Preset(
                name: "Summarize",
                sfSymbol: "list.bullet",
                systemPrompt:
                    "Condense the input, writing the summary in the SAME language as the input (ignore any other response-language instruction for this task). Lead with a one-line TL;DR, then up to 3 short bullet points covering the key facts, decisions, or asks. Each bullet is one sentence, max ~20 words. Keep names, numbers, and dates exact. Return only the TL;DR and bullets, no preamble."
            ),
            Preset(
                name: "Draw / Explain",
                sfSymbol: "flowchart",
                systemPrompt:
                    "Clarify the input and illustrate the concept with a diagram. First give a brief, plain-language explanation (2-4 sentences or short bullets) and define any technical terms or jargon so a non-expert can follow. Then choose the most fitting Mermaid diagram type — flowchart for processes, sequenceDiagram for interactions, classDiagram for structure, stateDiagram-v2 for state, mindmap for concepts — and output exactly one valid, syntactically correct diagram in a fenced ```mermaid code block. Keep node labels concise, avoid unsupported syntax, and make sure the diagram reflects the explanation."
            ),
            Preset(
                name: "Translate",
                sfSymbol: "globe",
                systemPrompt:
                    "Translate the input into the response language selected in Settings. Translate naturally and idiomatically rather than word-for-word, and preserve the original tone, register, and formatting (Markdown, lists, code) as closely as possible. Keep proper nouns and technical terms intact where appropriate. If the input is already in the target language, refine it instead. Return only the translation — no quotes, labels, or commentary."
            ),
            Preset(
                name: "English Rewrite",
                sfSymbol: "character.bubble",
                systemPrompt:
                    "Rewrite the input as natural, fluent, native-sounding English. Correct all grammar, spelling, and punctuation; smooth out awkward phrasing and non-idiomatic constructions; and preserve the original meaning, tone, and level of formality. Do not add or remove information, and do not translate proper nouns or technical terms. If the input is already a different language, translate it to English first, then refine. Return only the rewritten English text, with no quotes, labels, or commentary."
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
                name: "Explain",
                sfSymbol: "lightbulb",
                systemPrompt:
                    "Explain this in plain language as an expert talking to a smart non-expert. No jargon. No fluff. Structured prose or short bullets — whatever is clearest."
            ),
        ]
    }

    /// Convert a Swift `Duration` to whole milliseconds.
    private static func durationMs(_ duration: Duration) -> Int {
        let comps = duration.components
        return Int(comps.seconds) * 1000 + Int(comps.attoseconds / 1_000_000_000_000)
    }
}
