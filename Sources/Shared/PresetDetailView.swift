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
                                .font(.title2)
                                .fontWeight(.semibold)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    viewModel.renamePreset(id: preset.id, to: name)
                                }
                                .onChange(of: name) { _, newValue in
                                    viewModel.renamePreset(id: preset.id, to: newValue)
                                }
                            
                            Text("Click icon to change, or edit name above")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Run action / start chat button
                        Button(action: {
                            viewModel.startNewConversation(title: preset.name, presetId: preset.id)
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
                            .background(Color.accentCoral)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        // Delete button
                        Button(action: {
                            viewModel.deletePreset(id: preset.id)
                            viewModel.selectedPresetIdForDetail = nil
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
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
                            .font(.system(size: AppFont.pt(12), design: .monospaced))
                            .padding(12)
                            .background(Color.cardSurface)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.hairline, lineWidth: 1)
                            )
                            .frame(minHeight: 180)
                            .focused($isPromptFocused)
                            .onChange(of: systemPrompt) { _, newValue in
                                viewModel.setPresetPrompt(id: preset.id, prompt: newValue)
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
                .padding(28)
            }
            .onAppear {
                name = preset.name
                systemPrompt = preset.systemPrompt
                sfSymbol = preset.sfSymbol
            }
            .onChange(of: presetId) { _, newId in
                if let p = viewModel.presets.first(where: { $0.id == newId }) {
                    name = p.name
                    systemPrompt = p.systemPrompt
                    sfSymbol = p.sfSymbol
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
}
