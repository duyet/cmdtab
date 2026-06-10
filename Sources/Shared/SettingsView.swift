import SwiftUI

// MARK: - Settings View
/// Full floating panel: tab row at top, scrollable content per tab.
/// Presented over a scrim in MainView — instant, no animation.
public struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    private var selectedTab: String { viewModel.settingsTab }

    let languages = ["English", "Spanish", "French", "German", "Chinese", "Japanese", "Korean", "Vietnamese"]

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    viewModel.savePresets()
                    viewModel.toggleSettings()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Close settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Tab row — scrollable on narrow screens
            ScrollView(.horizontal, showsIndicators: false) {
                PillTabBar(
                    items: [
                        PillTabBar.Item(value: "general", label: "General"),
                        PillTabBar.Item(value: "profile", label: "Profile"),
                        PillTabBar.Item(value: "personalization", label: "Personalization"),
                        PillTabBar.Item(value: "cloudmodel", label: "Cloud Model"),
                    ],
                    selection: $viewModel.settingsTab
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1)

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.18), radius: 32, y: 8)
    }

    // MARK: - General Tab (theme, font, language)
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            #if os(macOS)
            settingsSection("APPEARANCE") {
                Picker("", selection: $viewModel.appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
            }
            #endif

            #if os(iOS)
            // Apple Intelligence status — prominent on iOS
            settingsSection("APPLE INTELLIGENCE") {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isLocalModelSupported ? "apple.intelligence" : "apple.logo")
                        .font(.system(size: 18))
                        .foregroundColor(viewModel.isLocalModelSupported ? .blue : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isLocalModelSupported ? "Available" : "Not Available")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Text(LocalModelClient.shared.availability.unavailableReason ?? "On-device model ready for local inference.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(viewModel.isLocalModelSupported ? Color.blue.opacity(0.06) : Color.primary.opacity(0.03))
                .cornerRadius(10)
            }
            #endif

            settingsSection("FONT SIZE") {
                Picker("", selection: $viewModel.fontScale) {
                    Text("Small").tag(CGFloat(0.9))
                    Text("Medium").tag(CGFloat(1.0))
                    Text("Large").tag(CGFloat(1.1))
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                .frame(maxWidth: 240, alignment: .leading)
            }

            settingsSection("RESPONSE LANGUAGE") {
                Picker("", selection: $viewModel.preferredLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                #if os(macOS)
                .pickerStyle(PopUpButtonPickerStyle())
                #else
                .pickerStyle(MenuPickerStyle())
                #endif
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }
        }
    }

    // MARK: - Profile Tab (name + activity)
    private var profileTabContent: some View {
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
                        .font(.system(size: 18, weight: .semibold))
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

            Text("Conversations are kept in memory only and reset when the app quits.")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }

    private var profileInitials: String {
        let parts = viewModel.userName.split(separator: " ").prefix(2)
        let initials = parts.compactMap { $0.first.map(String.init) }.joined()
        return initials.isEmpty ? "⌘" : initials.uppercased()
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Personalization Tab
    private var personalizationTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("PERSONALITY") {
                Picker("", selection: $viewModel.personality) {
                    ForEach(MainViewModel.personalityOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                #if os(macOS)
                .pickerStyle(PopUpButtonPickerStyle())
                #else
                .pickerStyle(MenuPickerStyle())
                #endif
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }

            settingsSection("CUSTOM INSTRUCTIONS") {
                TextEditor(text: $viewModel.customInstructions)
                    .font(.system(size: 12))
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
                        Text("Let cmdtab remember facts across conversations. Coming soon.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(true)
            }
        }
    }

    // MARK: - Cloud Model Tab (provider, endpoint, key, model)
    private var cloudModelTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsSection("API PROVIDER") {
                Picker("", selection: $viewModel.apiProvider) {
                    Text("anyrouter.dev").tag("anyrouter")
                    Text("Local Ollama").tag("ollama")
                    Text("OpenRouter").tag("openrouter")
                    Text("Google Gemini").tag("gemini")
                    Text("OpenAI").tag("openai")
                    Text("Custom").tag("custom")
                }
                #if os(macOS)
                .pickerStyle(PopUpButtonPickerStyle())
                #else
                .pickerStyle(MenuPickerStyle())
                #endif
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
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

            settingsSection("ENDPOINT URL") {
                TextField("https://...", text: $viewModel.endpointUrl)
                    .font(.system(size: 13))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            }

            settingsSection("API KEY / TOKEN (Keychain Protected)") {
                SecureField("Enter API Token...", text: $viewModel.apiKey)
                    .font(.system(size: 13))
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
                Picker("", selection: $viewModel.modelName) {
                    ForEach(ModelCatalog.entries) { entry in
                        Text(entry.displayName).tag(entry.id)
                    }
                    if !ModelCatalog.entries.contains(where: { $0.id == viewModel.modelName })
                        && !viewModel.modelName.isEmpty
                    {
                        Text(viewModel.modelName).tag(viewModel.modelName)
                    }
                }
                #if os(macOS)
                .pickerStyle(PopUpButtonPickerStyle())
                #else
                .pickerStyle(MenuPickerStyle())
                #endif
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }

            settingsSection("ON-DEVICE MODEL") {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isLocalModelSupported ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(viewModel.isLocalModelSupported ? .green : .secondary)
                        .font(.system(size: 13))
                    Text(LocalModelClient.shared.availability.unavailableReason ?? "Apple Intelligence — available")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Section helper
    @ViewBuilder
    private func settingsSection<Content: View>(_ heading: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }
}

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
