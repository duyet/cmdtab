import SwiftUI

// MARK: - Settings View
/// Full-window settings surface with a left sidebar and plain content pane.
public struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    private var selectedTab: String { viewModel.settingsTab }
    private var selectedTitle: String {
        switch selectedTab {
        case "profile": return "Profile"
        case "personalization": return "Personalization"
        case "cloudmodel": return "Cloud Model"
        default: return "General"
        }
    }

    private static let languages = ["English", "Spanish", "French", "German", "Chinese", "Japanese", "Korean", "Vietnamese"]

    @State private var showSettingsModelPicker: Bool = false
    @State private var settingsModelSearch: String = ""

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        #if os(iOS)
        iOSBody
        #else
        macOSBody
        #endif
    }

    #if os(iOS)
    @State private var showAbout = false

    // iPhone settings: a grouped list that pushes each section full-screen,
    // styled like the system Settings app. (NavigationSplitView collapses to a
    // single floating column on compact widths, so iOS gets its own stack.)
    private var iOSBody: some View {
        NavigationStack {
            List {
                Section {
                    settingsNavLink("General", icon: "gearshape") { generalTabContent }
                    settingsNavLink("Profile", icon: "person.circle") { profileTabContent }
                    settingsNavLink("Personalization", icon: "slider.horizontal.3") {
                        personalizationTabContent
                    }
                    settingsNavLink("Cloud Model", icon: "cloud") { cloudModelTabContent }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { closeButton }
                ToolbarItem(placement: .topBarTrailing) { infoButton }
            }
            .alert("MinhAgent", isPresented: $showAbout) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("A native conversation workspace with clipboard Quick Actions and "
                    + "on-device + cloud inference. Conversations stay in memory only.")
            }
        }
    }

    private var infoButton: some View {
        Button { showAbout = true } label: {
            Image(systemName: "info")
                .font(.system(size: AppFont.pt(15), weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
                .iOSGlassIconSurface()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("About MinhAgent")
    }

    private func settingsNavLink<Content: View>(
        _ title: String, icon: String, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        NavigationLink {
            SettingsDetailScreen(title: title, onSave: { viewModel.savePresets() }) {
                content()
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: AppFont.pt(16)))
        }
    }
    #else
    private var macOSBody: some View {
        // Content-only — sidebar nav is hosted in the main app sidebar.
        settingsContentPane
    }
    #endif

    /// macOS: settings detail content (title + scrollable tab content).
    /// Used when the main sidebar replaces itself with settings navigation.
    var settingsContentPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(selectedTitle)
                    .font(.system(size: AppFont.pt(17), weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                closeButton
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1)

            ScrollView {
                switch selectedTab {
                case "profile":
                    profileTabContent
                case "personalization":
                    personalizationTabContent
                case "cloudmodel":
                    cloudModelTabContent
                default:
                    generalTabContent
                }
            }
        }
        .background(Color.appBackground)
    }

    private func settingsSidebarItem(_ value: String, title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: AppFont.pt(13)))
            .tag(value)
    }

    private var closeButton: some View {
        Button(action: {
            viewModel.savePresets()
            viewModel.toggleSettings()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: AppFont.pt(12), weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
                .iOSGlassIconSurface()
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Close settings")
    }

    @ViewBuilder
    private var settingsSidebar: some View {
        #if os(macOS)
        List(selection: $viewModel.settingsTab) {
            Section {
                settingsSidebarItem("general", title: "General", icon: "gearshape")
                settingsSidebarItem("profile", title: "Profile", icon: "person.circle")
                settingsSidebarItem("personalization", title: "Personalization", icon: "slider.horizontal.3")
                settingsSidebarItem("cloudmodel", title: "Cloud Model", icon: "cloud")
            } header: {
                Text("Settings")
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        #else
        List {
            Section {
                settingsSidebarButton("general", title: "General", icon: "gearshape")
                settingsSidebarButton("profile", title: "Profile", icon: "person.circle")
                settingsSidebarButton("personalization", title: "Personalization", icon: "slider.horizontal.3")
                settingsSidebarButton("cloudmodel", title: "Cloud Model", icon: "cloud")
            } header: {
                Text("Settings")
            }
        }
        .listStyle(.sidebar)
        #endif
    }

    private func settingsSidebarButton(_ value: String, title: String, icon: String) -> some View {
        Button {
            viewModel.settingsTab = value
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: AppFont.pt(13)))
        }
    }

    // MARK: - General Tab (theme, font, language)
    private var generalTabContent: some View {
        #if os(macOS)
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $viewModel.appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(SegmentedPickerStyle())

                Picker("Font Size", selection: $viewModel.fontScale) {
                    Text("Small").tag(CGFloat(0.9))
                    Text("Medium").tag(CGFloat(1.0))
                    Text("Large").tag(CGFloat(1.1))
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section("Language") {
                Picker("Response Language", selection: $viewModel.preferredLanguage) {
                    ForEach(Self.languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        #else
        VStack(alignment: .leading, spacing: 20) {
            // Apple Intelligence status — prominent on iOS
            settingsSection("APPLE INTELLIGENCE") {
                VStack(alignment: .leading, spacing: 12) {
                    AppleIntelligenceAuditView()
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LocalModelClient.shared.availability.isAvailable
                            ? Color.blue.opacity(0.06) : Color.primary.opacity(0.03))
                        .cornerRadius(10)

                    localModelDetailsView
                }
            }

            settingsSection("FONT SIZE") {
                Picker("", selection: $viewModel.fontScale) {
                    Text("Small").tag(CGFloat(0.9))
                    Text("Medium").tag(CGFloat(1.0))
                    Text("Large").tag(CGFloat(1.1))
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                .accessibilityLabel("Font size")
                .frame(maxWidth: 240, alignment: .leading)
            }

            settingsSection("RESPONSE LANGUAGE") {
                Picker("", selection: $viewModel.preferredLanguage) {
                    ForEach(Self.languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        #endif
    }

    // MARK: - Profile Tab (name + activity)
    private var profileTabContent: some View {
        #if os(macOS)
        Form {
            Section {
                HStack(spacing: 14) {
                    AvatarCircle(
                        initials: profileInitials,
                        diameter: 48,
                        color: Color.accentCoral
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Your name", text: $viewModel.userName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: AppFont.pt(17), weight: .semibold))
                        Text("Used in the welcome headline")
                            .font(.system(size: AppFont.pt(11)))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(
                header: Text("Activity"),
                footer: Text("Conversations are stored locally on this device and never leave it.")
                    .font(.system(size: AppFont.pt(11)))
            ) {
                HStack(spacing: 0) {
                    profileStat(value: "\(viewModel.conversations.count)", label: "Conversations")
                    Divider().frame(height: 32)
                    profileStat(
                        value: "\(viewModel.conversations.reduce(0) { $0 + $1.messages.count })",
                        label: "Messages")
                    Divider().frame(height: 32)
                    profileStat(value: "\(viewModel.presets.count)", label: "Actions")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        #else
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                AvatarCircle(
                    initials: profileInitials,
                    diameter: 56,
                    color: Color.accentCoral
                )
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your name", text: $viewModel.userName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: AppFont.pt(18), weight: .semibold))
                    Text("Used in the welcome headline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)

            settingsSection("ACTIVITY") {
                HStack(spacing: 0) {
                    profileStat(value: "\(viewModel.conversations.count)", label: "Conversations")
                    Divider().frame(height: 32)
                    profileStat(
                        value: "\(viewModel.conversations.reduce(0) { $0 + $1.messages.count })",
                        label: "Messages")
                    Divider().frame(height: 32)
                    profileStat(value: "\(viewModel.presets.count)", label: "Actions")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.hairline, lineWidth: 1)
                )
                .cornerRadius(10)
            }

            Text("Conversations are stored locally on this device and never leave it.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        #endif
    }

    private var profileInitials: String {
        let parts = viewModel.userName.split(separator: " ").prefix(2)
        let initials = parts.compactMap { $0.first.map(String.init) }.joined()
        return initials.isEmpty ? "⌘" : initials.uppercased()
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: AppFont.pt(18), weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Personalization Tab
    private var personalizationTabContent: some View {
        #if os(macOS)
        Form {
            Section("Personality") {
                Picker("Style", selection: $viewModel.personality) {
                    ForEach(MainViewModel.personalityOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
            }

            Section(
                header: Text("System Prompt"),
                footer: Text("Overrides the built-in system instructions.")
                    .font(.system(size: AppFont.pt(11)))
            ) {
                TextEditor(text: $viewModel.systemPrompt)
                    .font(.system(size: AppFont.pt(12)))
                    .frame(minHeight: 80)
                Button("Reset to Default") {
                    viewModel.systemPrompt = MainViewModel.defaultSystemPrompt
                }
                .foregroundColor(.accentCoral)
            }

            Section(
                header: Text("Custom Instructions"),
                footer: Text("Added to every conversation's system prompt.")
                    .font(.system(size: AppFont.pt(11)))
            ) {
                TextEditor(text: $viewModel.customInstructions)
                    .font(.system(size: AppFont.pt(12)))
                    .frame(minHeight: 100)
            }

            Section("Memories") {
                Toggle("Enable memories", isOn: $viewModel.memoriesEnabled)
                    .disabled(true)
                Text("Let MinhAgent remember facts across conversations. Coming soon.")
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        #else
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("SYSTEM PROMPT") {
                TextEditor(text: $viewModel.systemPrompt)
                    .font(.system(size: AppFont.pt(12)))
                    .frame(height: 80)
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                Button("Reset to default") {
                    viewModel.systemPrompt = MainViewModel.defaultSystemPrompt
                }
                .font(.caption)
                .foregroundColor(.accentCoral)
            }

            settingsSection("PERSONALITY") {
                Picker("", selection: $viewModel.personality) {
                    ForEach(MainViewModel.personalityOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }

            settingsSection("CUSTOM INSTRUCTIONS") {
                TextEditor(text: $viewModel.customInstructions)
                    .font(.system(size: AppFont.pt(12)))
                    .frame(height: 110)
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                Text("Added to every conversation's system prompt.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }

            settingsSection("MEMORIES") {
                Toggle(isOn: $viewModel.memoriesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable memories")
                            .font(.body)
                        Text("Let MinhAgent remember facts across conversations. Coming soon.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        #endif
    }

    // MARK: - Cloud Model Tab (AnyRouter connection, provider, model, generation)
    private var cloudModelTabContent: some View {
        #if os(macOS)
        Form {
            Section {
                anyRouterConnectionBlock
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            } header: {
                Text("AnyRouter")
            } footer: {
                Text("Sign in to AnyRouter, paste a key, and verify. The key is stored only in Keychain.")
                    .font(.system(size: AppFont.pt(11)))
            }

            Section("API Provider") {
                providerPicker
                TextField("Endpoint URL", text: $viewModel.endpointUrl)
                    .font(.system(size: AppFont.pt(13)))
                keychainStatusRow
                SecureField("Paste API Token…", text: $viewModel.apiKey)
                    .font(.system(size: AppFont.pt(13)))
            }

            Section("Cloud Model") {
                cloudModelChooser
                cloudModelDetailsView
                    .listRowInsets(EdgeInsets())
            }

            Section {
                generationControls
            } header: {
                Text("Generation")
            } footer: {
                Text("Temperature, Top P, and Max Tokens are sent to every cloud request. Defaults match the provider.")
                    .font(.system(size: AppFont.pt(11)))
            }

            Section("On-Device Model") {
                AppleIntelligenceAuditView()
                    .padding(.vertical, 4)
                localModelDetailsView
                    .listRowInsets(EdgeInsets())
            }

            Section("Local Tools") {
                localToolDetailsView
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        #else
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("AnyRouter") {
                anyRouterConnectionBlock
            }

            settingsSection("API PROVIDER") {
                providerPicker
                    .frame(maxWidth: 220, alignment: .leading)
                TextField("https://...", text: $viewModel.endpointUrl)
                    .font(.system(size: AppFont.pt(13)))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                keychainStatusView
                    .padding(.top, 2)
                SecureField("Paste API Token...", text: $viewModel.apiKey)
                    .font(.system(size: AppFont.pt(13)))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            }

            settingsSection("CLOUD MODEL") {
                cloudModelChooser
                cloudModelDetailsView
                    .padding(.top, 6)
            }

            settingsSection("GENERATION") {
                generationControls
            }

            settingsSection("ON-DEVICE MODEL") {
                VStack(alignment: .leading, spacing: 12) {
                    AppleIntelligenceAuditView()
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(10)

                    localModelDetailsView
                }
            }

            settingsSection("LOCAL TOOLS") {
                localToolDetailsView
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        #endif
    }

    // MARK: AnyRouter connection block — login/consent + verify + dashboard.
    private var anyRouterConnectionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: connectionSymbol)
                    .font(.system(size: AppFont.pt(16), weight: .semibold))
                    .foregroundColor(connectionColor)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.anyRouterConnectionTitle)
                        .font(.system(size: AppFont.pt(13), weight: .semibold))
                        .foregroundColor(.primary)
                    Text(viewModel.anyRouterConnectionDetail)
                        .font(.system(size: AppFont.pt(11)))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if viewModel.isAnyRouterConnecting {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.connectAnyRouter()
                } label: {
                    Label("Connect", systemImage: "link")
                        .font(.system(size: AppFont.pt(12), weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    viewModel.verifyAnyRouterConnection()
                } label: {
                    Label("Verify", systemImage: "checkmark.seal")
                        .font(.system(size: AppFont.pt(12)))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    viewModel.openAnyRouterKeysDashboard()
                } label: {
                    Label("Get a key", systemImage: "arrow.up.right.square")
                        .font(.system(size: AppFont.pt(12)))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            SecureField("Paste sk-ar-v1-… key", text: $viewModel.apiKey)
                .font(.system(size: AppFont.pt(13)))
                .textFieldStyle(PlainTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.hairline.opacity(0.6), lineWidth: 1)
                )
        }
    }

    private var connectionSymbol: String {
        if viewModel.isAnyRouterConnecting { return "arrow.triangle.2.circlepath" }
        return viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "cloud.slash" : "checkmark.seal.fill"
    }

    private var connectionColor: Color {
        if viewModel.isAnyRouterConnecting { return .secondary }
        let title = viewModel.anyRouterConnectionTitle.lowercased()
        if title.contains("connected") { return .green }
        if title.contains("fail") || title.contains("not") { return .orange }
        return .accentColor
    }

    // MARK: API provider picker (shared).
    private var providerPicker: some View {
        Picker("Provider", selection: $viewModel.apiProvider) {
            Text("AnyRouter").tag("anyrouter")
            Text("Local Ollama").tag("ollama")
            Text("OpenRouter").tag("openrouter")
            Text("Google Gemini").tag("gemini")
            Text("OpenAI").tag("openai")
            Text("Custom").tag("custom")
        }
        #if os(iOS)
        .pickerStyle(MenuPickerStyle())
        .labelsHidden()
        #endif
        .onProviderChange(of: viewModel.apiProvider) { newValue in
            switch newValue {
            case "anyrouter":
                viewModel.endpointUrl = "https://anyrouter.dev/api/v1"
                viewModel.modelName = MainViewModel.defaultModelId
            case "ollama":
                viewModel.endpointUrl = "http://localhost:11434/v1"
                viewModel.modelName = "llama3"
            case "openrouter":
                viewModel.endpointUrl = "https://openrouter.ai/api/v1"
                viewModel.modelName = "google/gemini-flash-1.5"
            case "openai":
                viewModel.endpointUrl = "https://api.openai.com/v1"
                viewModel.modelName = "gpt-4o"
            case "gemini":
                viewModel.endpointUrl = "https://generativelanguage.googleapis.com/v1beta/openai"
                viewModel.modelName = "gemini-1.5-flash"
            default:
                break
            }
        }
    }

    private var keychainStatusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.apiKey.isEmpty ? "key.slash" : "key.fill")
                .font(.system(size: AppFont.pt(12), weight: .semibold))
                .foregroundColor(viewModel.apiKey.isEmpty ? .secondary : .green)
                .frame(width: 16, height: 16)
            Text(viewModel.apiKey.isEmpty ? "No cloud key loaded" : "Cloud key loaded")
                .font(.system(size: AppFont.pt(12.5)))
                .foregroundColor(viewModel.apiKey.isEmpty ? .secondary : .primary)
            Spacer(minLength: 0)
        }
    }

    // MARK: Dynamic cloud model chooser — opens the searchable popover.
    private var cloudModelChooser: some View {
        HStack(spacing: 8) {
            Image(systemName: currentCloudModelIcon)
                .font(.system(size: AppFont.pt(12)))
                .foregroundColor(.accentColor)
                .frame(width: 18)
            Text(currentCloudModelDisplayName)
                .font(.system(size: AppFont.pt(13)))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Button {
                settingsModelSearch = ""
                showSettingsModelPicker.toggle()
            } label: {
                Label("Change", systemImage: "chevron.up.chevron.down")
                    .font(.system(size: AppFont.pt(12), weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .popover(isPresented: $showSettingsModelPicker) {
                ModelPickerPopover(
                    entries: viewModel.cloudModelEntries,
                    selectedId: viewModel.modelName,
                    supportsReasoning: viewModel.modelSupportsReasoning,
                    reasoningEffort: $viewModel.reasoningEffort,
                    search: $settingsModelSearch
                ) { id in
                    viewModel.modelName = id
                    showSettingsModelPicker = false
                }
            }
        }
    }

    // MARK: Generation controls — temperature / top-p / max-tokens / reasoning.
    private var generationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Temperature")
                        .font(.system(size: AppFont.pt(12.5)))
                    Spacer()
                    Text(String(format: "%.2f", viewModel.temperature))
                        .font(.system(size: AppFont.pt(12), design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.temperature, in: 0...2, step: 0.05) {
                    Text("Temperature")
                } minimumValueLabel: {
                    Text("0").font(.system(size: AppFont.pt(9))).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("2").font(.system(size: AppFont.pt(9))).foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Top P")
                        .font(.system(size: AppFont.pt(12.5)))
                    Spacer()
                    Text(String(format: "%.2f", viewModel.topP))
                        .font(.system(size: AppFont.pt(12), design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $viewModel.topP, in: 0...1, step: 0.05) {
                    Text("Top P")
                } minimumValueLabel: {
                    Text("0").font(.system(size: AppFont.pt(9))).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("1").font(.system(size: AppFont.pt(9))).foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Max Tokens")
                    .font(.system(size: AppFont.pt(12.5)))
                Spacer()
                Stepper(value: $viewModel.maxTokens, in: 0...32000, step: 256) {
                    Text(viewModel.maxTokens == 0 ? "Auto" : "\(viewModel.maxTokens)")
                        .font(.system(size: AppFont.pt(12), design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.modelSupportsReasoning {
                Divider().padding(.vertical, 2)
                HStack {
                    Text("Reasoning")
                        .font(.system(size: AppFont.pt(12.5)))
                    Spacer()
                    Picker("Reasoning", selection: $viewModel.reasoningEffort) {
                        ForEach(ModelCatalog.reasoningEfforts, id: \.self) { effort in
                            Text(effort.capitalized).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    #if os(iOS)
                    .labelsHidden()
                    #endif
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var currentCloudModelIcon: String {
        viewModel.cloudModelEntries.first(where: { $0.id == viewModel.modelName })?.sfSymbol ?? "sparkles"
    }

    // MARK: - Section helper
    @ViewBuilder
    private func settingsSection<Content: View>(_ heading: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.system(size: AppFont.pt(11), weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private var localModelDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODEL METADATA")
                .font(.system(size: AppFont.pt(10), weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            VStack(spacing: 0) {
                metadataRow(label: "Framework", value: "FoundationModels SDK")
                Divider()
                metadataRow(label: "Context Limit", value: "4,096 tokens")
                Divider()
                metadataRow(label: "System Language", value: "\(AppleIntelligenceAudit.primaryLanguageDisplayName) (\(AppleIntelligenceAudit.primaryLanguageID))")
                Divider()
                metadataRow(label: "Language Match", value: AppleIntelligenceAudit.languageIsLikelySupported(AppleIntelligenceAudit.primaryLanguageID) ? "Supported" : "May be unsupported")
            }
            .background(Color.cardSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hairline.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var keychainStatusView: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.apiKey.isEmpty ? "key.slash" : "key.fill")
                .font(.system(size: AppFont.pt(12), weight: .semibold))
                .foregroundColor(viewModel.apiKey.isEmpty ? .secondary : .green)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.apiKey.isEmpty ? "No cloud key loaded" : "Cloud key loaded")
                    .font(.system(size: AppFont.pt(12), weight: .semibold))
                Text("Saved with Keychain service minhagent.app and account token.")
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.hairline.opacity(0.5), lineWidth: 1))
    }

    private var cloudModelDetailsView: some View {
        VStack(spacing: 0) {
            metadataRow(label: "Model ID", value: viewModel.modelName)
            Divider()
            metadataRow(label: "Display Name", value: currentCloudModelDisplayName)
            Divider()
            metadataRow(
                label: "Reasoning",
                value: viewModel.modelSupportsReasoning ? viewModel.reasoningEffort.capitalized : "Not supported"
            )
        }
        .background(Color.cardSurface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.hairline.opacity(0.5), lineWidth: 1)
        )
    }

    private var localToolDetailsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: localToolBinding("calculator")) {
                settingsToggleLabel(
                    title: "Calculator",
                    detail: "Evaluate simple arithmetic expressions when local tool calling is available.",
                    icon: "plus.forwardslash.minus"
                )
            }
            Toggle(isOn: localToolBinding("system_clock")) {
                settingsToggleLabel(
                    title: "System Clock",
                    detail: "Read the current system date and time for local model answers.",
                    icon: "clock"
                )
            }
            Text("Tools are attached only to the local FoundationModels path. Cloud models receive normal OpenAI-compatible chat messages.")
                .font(.system(size: AppFont.pt(11)))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func settingsToggleLabel(title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: AppFont.pt(12), weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: AppFont.pt(12.5), weight: .semibold))
                Text(detail)
                    .font(.system(size: AppFont.pt(11)))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func localToolBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.enabledLocalTools.contains(name) },
            set: { enabled in
                if enabled {
                    viewModel.enabledLocalTools.insert(name)
                } else {
                    viewModel.enabledLocalTools.remove(name)
                }
            }
        )
    }

    private var currentCloudModelDisplayName: String {
        viewModel.cloudModelEntries.first(where: { $0.id == viewModel.modelName })?.displayName
            ?? viewModel.modelName
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: AppFont.pt(11.5)))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: AppFont.pt(11.5), weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#if os(iOS)
// MARK: - Settings Detail Screen (iOS)
/// A pushed settings section with a grouped background and a Done checkmark that
/// saves and pops. Reads its own `dismiss` so the checkmark returns to the list.
private struct SettingsDetailScreen<Content: View>: View {
    let title: String
    let onSave: () -> Void
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.appBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: AppFont.pt(14), weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                        .iOSGlassIconSurface()
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Save and go back")
            }
        }
    }
}
#endif

extension View {
    @ViewBuilder
    func onProviderChange(of value: String, perform action: @escaping (String) -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}
