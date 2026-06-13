import SwiftUI

struct PresetDetailView: View {
    @ObservedObject var viewModel: MainViewModel
    let presetId: UUID
    
    private var preset: Preset? {
        viewModel.presets.first(where: { $0.id == presetId })
    }
    
    @State private var name: String = ""
    @State private var systemPrompt: String = ""
    @State private var sfSymbol: String = "sparkles"
    
    @FocusState private var isPromptFocused: Bool
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        if let preset = preset {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header row with Icon, Name, and Actions
                    HStack(spacing: 16) {
                        // Icon selection menu
                        Menu {
                            ForEach(Preset.iconChoices, id: \.self) { symbol in
                                Button {
                                    viewModel.setPresetIcon(id: preset.id, sfSymbol: symbol)
                                    sfSymbol = symbol
                                } label: {
                                    Label(symbol, systemImage: symbol)
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.accentCoral.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                Image(systemName: sfSymbol)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.accentCoral)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change preset icon")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Preset Name", text: $name)
                                .font(.system(size: AppFont.pt(20), weight: .semibold))
                                .textFieldStyle(.plain)
                                .focused($isNameFocused)
                                .onSubmit {
                                    savePendingName(for: preset)
                                }
                                .onChange(of: isNameFocused) { _, focused in
                                    if !focused {
                                        savePendingName(for: preset)
                                    }
                                }
                            
                            Text("Click icon to change, or edit name above")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Run action / start chat button
                        Button(action: {
                            let chatTitle = savePendingName(for: preset)
                            savePendingPrompt(for: preset)
                            viewModel.startNewConversation(title: chatTitle, presetId: preset.id)
                            viewModel.sidebarMode = "chat"
                            viewModel.selectedPresetIdForDetail = nil
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text("Start Chat")
                            }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(minHeight: 44)
                            .background(Color.accentCoral)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Starts a new conversation with this preset's instructions")

                        // Delete button
                        Button(action: {
                            viewModel.deletePreset(id: preset.id)
                            viewModel.selectedPresetIdForDetail = nil
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete action")
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Prompt section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SYSTEM PROMPT / INSTRUCTIONS")
                            .font(.system(size: AppFont.pt(10), weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Text("This prompt defines the AI's behavior when this preset is run.")
                            .font(.system(size: AppFont.pt(12)))
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $systemPrompt)
                            .font(.system(size: AppFont.pt(13), design: .monospaced))
                            .padding(12)
                            .background(Color.cardSurface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.hairline, lineWidth: 1)
                            )
                            .frame(minHeight: 180)
                            .focused($isPromptFocused)
                            .onChange(of: isPromptFocused) { _, focused in
                                if !focused {
                                    savePendingPrompt(for: preset)
                                }
                            }
                    }
                    
                    // Helper/instructions for testing
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW TO RUN THIS PRESET")
                            .font(.system(size: AppFont.pt(10), weight: .bold))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.accentCoral)
                                .frame(width: 16)
                            Text("Copy any text to your clipboard, and click the preset pill on the landing screen, or click 'Start Chat' and send a message.")
                                .font(.system(size: AppFont.pt(12)))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.hairline.opacity(0.5), lineWidth: 1)
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .onAppear {
                loadPreset(preset)
            }
            .onChange(of: presetId) { oldId, newId in
                if let oldPreset = viewModel.presets.first(where: { $0.id == oldId }) {
                    savePendingName(for: oldPreset)
                    savePendingPrompt(for: oldPreset)
                }
                if let p = viewModel.presets.first(where: { $0.id == newId }) {
                    loadPreset(p)
                }
            }
            .onDisappear {
                if viewModel.presets.contains(where: { $0.id == preset.id }) {
                    savePendingName(for: preset)
                    savePendingPrompt(for: preset)
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Preset not found")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadPreset(_ preset: Preset) {
        name = preset.name
        systemPrompt = preset.systemPrompt
        sfSymbol = preset.sfSymbol
    }

    private func savePendingPrompt(for preset: Preset) {
        guard systemPrompt != preset.systemPrompt else { return }
        viewModel.setPresetPrompt(id: preset.id, prompt: systemPrompt)
    }

    @discardableResult
    private func savePendingName(for preset: Preset) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            name = preset.name
            return preset.name
        }
        guard trimmedName != preset.name else {
            name = preset.name
            return preset.name
        }
        viewModel.renamePreset(id: preset.id, to: trimmedName)
        name = trimmedName
        return trimmedName
    }
}
